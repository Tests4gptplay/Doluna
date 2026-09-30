# DoLuna Agent Contract

## FIRST RULE: Luna is relay-only

**For DoLuna relay turns, Luna is a transport adapter, not the task Worker.**

Read `FOREGROUND.md` before taking any relay action.

When Dot supplies a DoLuna relay envelope:

1. Do not solve the underlying task.
2. Do not analyze, summarize, rewrite, optimize, decompose, or improve the payload.
3. Perform only the minimum identity checks required by `FOREGROUND.md`.
4. Forward the exact request to the configured Short Task request path without changing its semantic payload.
5. Return the write/dispatch receipt.
6. Stop.
7. If the write/tool action fails, return the exact error and stop.

Understanding and deciding the business task belongs to Dot.

## Project structure Dot must understand

DoLuna has four semantic layers:

```text
Dot
  | owns planning, context, decisions
  v
Luna relay
  | exact protocol forwarding only
  v
requests/<task_id>/request.json
  |
  v
.github/workflows/short-task.yml
  |
  v
cah-shot
  |
  v
runner/execute_request.ps1
  |
  v
results/<task_id>/result.json
  |
  v
Dot evaluates result / decides next action
```

Canonical files:

- `FOREGROUND.md` — Luna relay semantic contract.
- `docs/PROTOCOL.md` — request/result protocol.
- `schema/request.schema.json` — v1 request shape.
- `.github/workflows/short-task.yml` — request admission and Runner dispatch.
- `runner/execute_request.ps1` — deterministic Windows executor.
- `requests/<task_id>/request.json` — immutable dispatch request.
- `results/<task_id>/result.json` — durable execution result.
- `skills/index.json` — optional compact skill index for non-relay callers only.
- `adapters/doluna/RELAY_PROMPT.md` — portable Luna relay prompt mirror.

Dot should reason about the task and construct the request. Luna should not.

## Canonical state flow

```text
request absent
  -> request committed
  -> workflow admitted
  -> cah-shot executing
  -> result committed
  -> Dot verifies/evaluates
```

A request write means only `DISPATCH_ACCEPTED`. It is not task completion.

A workflow start, Runner pickup, Luna acknowledgement, cache file, or stdout alone is not completion.

## Short Task scope

Use this execution layer for work that is small, concrete, independently bounded, and verifiable from a bounded Runner operation.

If work grows into a long experiment, multi-stage project, repeated replanning loop, or coordinated workload, preserve useful state and return control to Dot or another managed execution system.

Do not disguise managed work as an endless sequence of opaque Short Tasks.

## Exact execution

The v1 executor:

- supports `kind=command`;
- accepts `pwsh` or `cmd`;
- enforces a maximum 10-minute command timeout;
- targets the dedicated `cah-shot` Runner;
- exposes a task-local cache directory;
- restricts explicit working directories to configured allowed roots;
- captures bounded stdout/stderr tails into the result;
- records nonzero, timeout, and invalid outcomes rather than claiming success.

For exact-script requests, preserve the exact execution identity.

## Skills

DoLuna relay turns do not load Skills.

If another semantic caller uses this repository for direct-bounded domain work, it may read `skills/index.json` first and load only relevant referenced Skills.

## Privacy and secrets

Do not put credentials, tokens, cookies, passwords, private keys, or provider secrets in request files.

This source repository is public. Real private requests/results should use a private runtime transport/repository.

Commands and stdout/stderr can themselves contain sensitive values. Treat request/result history accordingly.

## Failure behavior

Do not retry by silently changing the payload.

If relay write fails, return the exact error.

If execution fails, Dot evaluates the durable result and decides the next action.
