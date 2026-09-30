param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingPath([string]$Path) {
    return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

function Test-IsUnderRoot([string]$Path, [string]$Root) {
    $p = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $r = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($p.Equals($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $p.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CompactTail([string]$Path, [int]$MaxChars = 12000) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return '' }
    if ($text.Length -le $MaxChars) { return $text }
    return $text.Substring($text.Length - $MaxChars)
}

function Write-Result([string]$TaskId, [hashtable]$Body) {
    $safeId = if ($TaskId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') { $TaskId } else { '_invalid' }
    $resultDir = Join-Path $script:RepoRootResolved (Join-Path 'results' $safeId)
    New-Item -ItemType Directory -Path $resultDir -Force | Out-Null
    $resultPath = Join-Path $resultDir 'result.json'
    $Body['v'] = 1
    $Body['task_id'] = $TaskId
    ($Body | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $resultPath -Encoding utf8
    Write-Host "SHORT_TASK_RESULT=$resultPath"
}

$script:RepoRootResolved = Resolve-ExistingPath $RepoRoot
$requestResolved = Resolve-ExistingPath $RequestPath
$taskId = Split-Path -Leaf (Split-Path -Parent $requestResolved)
$started = [DateTimeOffset]::UtcNow

try {
    $requestsRoot = Join-Path $script:RepoRootResolved 'requests'
    if (-not (Test-IsUnderRoot $requestResolved $requestsRoot)) {
        throw "Request path is outside repository requests root: $requestResolved"
    }

    $request = Get-Content -LiteralPath $requestResolved -Raw | ConvertFrom-Json -ErrorAction Stop
    if ($request.v -ne 1) { throw 'Only protocol v=1 is supported.' }
    if ($request.task_id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') { throw 'Invalid task_id.' }
    $taskId = [string]$request.task_id

    $parentId = Split-Path -Leaf (Split-Path -Parent $requestResolved)
    if ($parentId -ne $taskId) { throw "Request directory does not match task_id." }
    if ($request.kind -ne 'command') { throw 'Only kind=command is supported in v1.' }
    if ($request.shell -notin @('pwsh', 'cmd')) { throw 'shell must be pwsh or cmd.' }

    $command = [string]$request.command
    if ([string]::IsNullOrWhiteSpace($command)) { throw 'command must not be empty.' }
    if ($command.Length -gt 65536) { throw 'command exceeds 65536 characters.' }

    $timeoutSeconds = 300
    if ($null -ne $request.PSObject.Properties['timeout_seconds'] -and $null -ne $request.timeout_seconds) {
        $timeoutSeconds = [int]$request.timeout_seconds
    }
    if ($timeoutSeconds -lt 1 -or $timeoutSeconds -gt 600) {
        throw 'timeout_seconds must be between 1 and 600.'
    }

    $cacheRoot = $env:SHORT_TASK_CACHE_ROOT
    if ([string]::IsNullOrWhiteSpace($cacheRoot)) {
        if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
            throw 'SHORT_TASK_CACHE_ROOT is unset and RUNNER_TEMP is unavailable.'
        }
        $cacheRoot = Join-Path $env:RUNNER_TEMP 'short-task-cache'
    }
    New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    $cacheRoot = Resolve-ExistingPath $cacheRoot

    $cacheDir = Join-Path $cacheRoot $taskId
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    $cacheDir = Resolve-ExistingPath $cacheDir

    $allowedRoots = New-Object System.Collections.Generic.List[string]
    $allowedRoots.Add($script:RepoRootResolved)
    $allowedRoots.Add($cacheRoot)

    if (-not [string]::IsNullOrWhiteSpace($env:SHORT_TASK_ALLOWED_ROOTS)) {
        foreach ($candidate in ($env:SHORT_TASK_ALLOWED_ROOTS -split ';')) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
                throw "Configured allowed root does not exist: $candidate"
            }
            $allowedRoots.Add((Resolve-ExistingPath $candidate))
        }
    }

    $workingDirectory = $cacheDir
    if ($null -ne $request.PSObject.Properties['working_directory'] -and
        $null -ne $request.working_directory -and
        -not [string]::IsNullOrWhiteSpace([string]$request.working_directory)) {
        $workingDirectory = Resolve-ExistingPath ([string]$request.working_directory)
        $approved = $false
        foreach ($root in $allowedRoots) {
            if (Test-IsUnderRoot $workingDirectory $root) { $approved = $true; break }
        }
        if (-not $approved) {
            throw "working_directory is outside configured allowed roots: $workingDirectory"
        }
    }

    $stdoutPath = Join-Path $cacheDir 'stdout.log'
    $stderrPath = Join-Path $cacheDir 'stderr.log'
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    $env:SHORT_TASK_ID = $taskId
    $env:SHORT_TASK_CACHE_DIR = $cacheDir
    $env:SHORT_TASK_REPO_ROOT = $script:RepoRootResolved
    $env:SHORT_TASK_REQUEST_PATH = $requestResolved

    if ($request.shell -eq 'pwsh') {
        $scriptPath = Join-Path $cacheDir 'task.ps1'
        Set-Content -LiteralPath $scriptPath -Value $command -Encoding utf8
        $filePath = 'pwsh.exe'
        $argumentList = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    } else {
        $scriptPath = Join-Path $cacheDir 'task.cmd'
        Set-Content -LiteralPath $scriptPath -Value $command -Encoding ascii
        $filePath = 'cmd.exe'
        $argumentList = @('/d', '/s', '/c', ('"{0}"' -f $scriptPath))
    }

    $startArgs = @{
        FilePath = $filePath
        ArgumentList = $argumentList
        WorkingDirectory = $workingDirectory
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError = $stderrPath
        PassThru = $true
        NoNewWindow = $true
    }
    $process = Start-Process @startArgs

    $timedOut = -not $process.WaitForExit($timeoutSeconds * 1000)
    $exitCode = $null

    if ($timedOut) {
        & taskkill.exe /PID $process.Id /T /F *> $null
        try { $process.WaitForExit(5000) | Out-Null } catch {}
    } else {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }

    $ended = [DateTimeOffset]::UtcNow
    $status = if ($timedOut) { 'timed_out' } elseif ($exitCode -eq 0) { 'succeeded' } else { 'failed' }
    $metadata = if ($null -ne $request.PSObject.Properties['metadata']) { $request.metadata } else { $null }

    Write-Result $taskId @{
        status = $status
        shell = [string]$request.shell
        working_directory = $workingDirectory
        started_at = $started.ToString('o')
        ended_at = $ended.ToString('o')
        duration_ms = [int64]($ended - $started).TotalMilliseconds
        exit_code = $exitCode
        timed_out = $timedOut
        stdout_tail = Get-CompactTail $stdoutPath
        stderr_tail = Get-CompactTail $stderrPath
        cache_dir = $cacheDir
        metadata = $metadata
    }

    if ($status -eq 'succeeded') { exit 0 }
    exit 1
}
catch {
    $ended = [DateTimeOffset]::UtcNow
    Write-Result $taskId @{
        status = 'invalid'
        started_at = $started.ToString('o')
        ended_at = $ended.ToString('o')
        duration_ms = [int64]($ended - $started).TotalMilliseconds
        exit_code = $null
        timed_out = $false
        stdout_tail = ''
        stderr_tail = [string]$_.Exception.Message
        cache_dir = $null
        metadata = $null
    }
    Write-Error $_
    exit 2
}
