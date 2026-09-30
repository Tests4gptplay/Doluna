# DoLuna

> ## Luna Relay Semantic Contract — READ THIS FIRST
>
> **Luna is a transport relay, not a Worker.**
>
> When a Dot-created Work task contains a DoLuna envelope, Luna must:
>
> 1. **Do not solve the task.**
> 2. **Do not analyze, summarize, rewrite, optimize, decompose, or improve the payload.**
> 3. Validate only the minimum envelope identity: `task_id`, `request_path`, and `request_json.task_id` must agree.
> 4. Forward the caller-provided Short Task request to the configured request surface **without changing its semantic payload**.
> 5. Return only the write/dispatch receipt needed by Dot to know the request was accepted.
> 6. Stop immediately after the relay action.
> 7. If the write fails, return the exact transport/tool error and stop. Do not improvise a replacement task.
>
> The authoritative contract is in **[FOREGROUND.md](FOREGROUND.md)** and is also enforced by **[AGENTS.md](AGENTS.md)** / **[AGENT.md](AGENT.md)**.

**DoLuna** is an experimental project that connects a persistent Dot planner to a standalone Short Task execution layer through an intentionally thin Luna relay.

```text
                         Dot
            planner / semantic owner
              /                    \
             / READ                 \ WRITE / DISPATCH
            v                        v
           Git                  Luna Work
   repo state + results         relay only
            ^                        |
            |                        | exact Git write
            |                        v
            |              requests/<task_id>/request.json
            |                        |
            |                        v
            |                 Short Task workflow
            |                        |
            |                        v
            +-------------------- cah-shot
                         executes and writes result
```

The project intentionally separates four concerns:

- **Dot** — reads Git directly, owns context/planning/decisions, and reads/evaluates durable results directly.
- **Luna** — write/dispatch relay only; it receives a fully formed request from Dot and performs the required Git mutation.
- **Git/request-result transport** — durable state, request, and result surface.
- **Short Task Runner** — deterministic host execution.

The normal read path does **not** pass through Luna. Luna is invoked only when Dot needs the Work-side relay to create the exact Git request that triggers execution.

The key experiment is whether a general-purpose model can be constrained to behave like a very thin protocol bridge while all substantive task reasoning stays with Dot.

## Why this architecture

DoLuna does not try to build another full agent inside Work.

Instead, the intended loop is:

```text
Dot reads Git directly
  -> Dot decides
  -> Luna writes exact request to Git
  -> Runner executes
  -> Runner writes result to Git
  -> Dot reads Git directly and evaluates
```

Luna should not inspect a project, plan a repair, choose a command, or reason about the host task. It should only carry an already-decided request across the boundary.

## What Luna must never do

For a DoLuna relay turn, Luna must not:

- solve the underlying task;
- inspect unrelated repository files;
- read the whole project "for context";
- choose a better command;
- change the command;
- change `shell`, `timeout_seconds`, `working_directory`, or metadata;
- split or merge tasks;
- start Codex;
- start another Worker;
- turn the relay into a long-running Work task;
- poll the Runner as part of the relay turn;
- claim execution succeeded merely because dispatch succeeded.

A successful request write means only:

```text
DISPATCH_ACCEPTED
```

It does **not** mean:

```text
TASK_SUCCEEDED
```

Only the later durable result can establish execution outcome.

## Short Task protocol

A caller writes one immutable request:

```text
requests/<task_id>/request.json
```

The dedicated Short Task Runner executes it and writes:

```text
results/<task_id>/result.json
```

The result is the durable execution record.

See [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Example request

```json
{
  "v": 1,
  "task_id": "hello-001",
  "kind": "command",
  "shell": "pwsh",
  "command": "Write-Output 'hello from DoLuna'",
  "timeout_seconds": 120,
  "working_directory": null,
  "metadata": {
    "origin": "dot"
  }
}
```

## Why Short Task is standalone

This project extracts the useful CAH Short Task pattern without importing the full managed-task state machine.

Included:

- dedicated `cah-shot` Runner identity;
- bounded host commands;
- hard timeout;
- immutable request identity;
- durable result;
- optional task cache/checkpoints;
- allowed-root checks;
- exact `pwsh` / `cmd` execution.

Not included:

- Planner / Worker / Helper state machines;
- Task Cell lifecycle;
- browser conversation rollover;
- managed Worker pools;
- managed workload scheduling.

## Repository map

```text
AGENTS.md
AGENT.md
FOREGROUND.md
adapters/doluna/RELAY_PROMPT.md
.github/workflows/short-task.yml
runner/execute_request.ps1
schema/request.schema.json
docs/PROTOCOL.md
docs/INSTALL.md
examples/hello.request.json
skills/index.json
```

## Privacy and trust boundary

This repository is public source code.

Real Short Task requests can contain commands, project names, paths, arguments, or other private data, and results can contain stdout/stderr. Therefore private workloads should use a private runtime request/result repository or another private transport derived from this source.

Also remember:

> Write authority to an accepted Short Task request is effectively command authority on the attached self-hosted Runner within its configured allowed roots.

Do not attach a privileged Runner to an untrusted request surface.

## Agent read order

Any AI operating this repository should read:

1. `AGENTS.md`
2. `FOREGROUND.md`
3. `docs/PROTOCOL.md`
4. only then the exact task/request it needs

A DoLuna relay turn should **not** load the Skill catalog or unrelated repository context.

## Status

Experimental.

The implementation is intentionally small so the core Dot -> Luna relay -> Short Task -> result loop can be tested and refined without dragging in a larger orchestration system.
