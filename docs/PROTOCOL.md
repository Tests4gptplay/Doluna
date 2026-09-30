# Short Task Protocol v1

## Request

Canonical path:

```text
requests/<task_id>/request.json
```

Example:

```json
{
  "v": 1,
  "task_id": "hello-001",
  "kind": "command",
  "shell": "pwsh",
  "command": "Write-Output 'hello from short task'",
  "timeout_seconds": 120,
  "working_directory": null,
  "metadata": {
    "origin": "dot"
  }
}
```

Rules:

- `task_id` matches `^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$`.
- The parent request directory name equals `task_id`.
- v1 supports only `kind=command`.
- `shell` is `pwsh` or `cmd`.
- `timeout_seconds` defaults to 300 and may not exceed 600.
- Empty commands are rejected.
- Null/omitted `working_directory` means the task cache.
- Explicit working directories must resolve under configured allowed roots.
- A submitted request is immutable. Retry with a new `task_id`.

## Luna relay invariant

Luna does not derive this request.

Dot (or another semantic owner) derives it. Luna only preserves and writes it.

Allowed relay transition:

```text
envelope received -> identity valid -> request written -> receipt returned
```

No business-task reasoning belongs in that transition.

## Runner environment

Every command inherits:

```text
SHORT_TASK_ID
SHORT_TASK_CACHE_DIR
SHORT_TASK_REPO_ROOT
SHORT_TASK_REQUEST_PATH
```

## Result

Canonical path:

```text
results/<task_id>/result.json
```

Terminal statuses:

- `succeeded`
- `failed`
- `timed_out`
- `invalid`

The workflow may itself be red after a failed/timed-out/invalid command while still successfully committing `result.json`.

The durable result is the execution record.

## State model

```text
absent
  -> request committed
  -> workflow admitted
  -> runner executing
  -> result committed
  -> Dot/caller verifies evidence
```

A successful Luna write covers only the first transition.

## Concurrency

v1 serializes execution per repository through the workflow concurrency group.

A future version can add lanes without changing request/result identity.

## Security and privacy

An accepted request is an authorized remote command request.

Repository request-write authority is therefore equivalent to command authority on the Shot Runner within configured allowed roots.

Request contents and result stdout/stderr may contain sensitive information. Use a private runtime transport for private workloads.


## DoLuna transport envelope

The Short Task request file itself is authored by Dot.

For the Luna relay, Dot should provide the complete serialized request file as `request_content`.

```json
{
  "protocol": "DOLUNA_RELAY_V1",
  "repository": "OWNER/RUNTIME-REPO",
  "branch": "main",
  "task_id": "example-001",
  "request_path": "requests/example-001/request.json",
  "request_content": "<complete request.json file body authored by Dot>"
}
```

Luna copies `request_content` to `request_path`. Luna does not derive or construct the Short Task request.
