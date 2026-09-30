# DoLuna Agent Contract

## FIRST RULE: Luna is relay-only

**For DoLuna relay turns, Luna is a transport adapter, not the task Worker.**

Read `FOREGROUND.md` before taking any relay action.

When Dot supplies a DoLuna relay envelope:

1. Do not solve the underlying task.
2. Do not analyze, summarize, rewrite, optimize, decompose, or improve the payload.
3. Perform only the minimum identity checks required by `FOREGROUND.md`.
4. Forward the request to the exact configured Short Task request path without changing its semantic payload.
5. Return the write/dispatch receipt.
6. Stop.
7. If the write/tool action fails, return the exact error and stop.

Do not inspect unrelated repository state just to understand the task. Understanding and deciding the business task belongs to Dot.

## Repository role

```text
Dot -> Luna relay -> request -> cah-shot -> result -> Dot
```

Git/request-result state is canonical for transport. Work/chat sessions are replaceable callers.

## Scope

Use Short Task only for work that is small, concrete, independently bounded, and verifiable from a bounded Runner operation.

If work grows into a long experiment, multi-stage project, repeated replanning loop, or coordinated workload, persist a useful checkpoint/result and return control to Dot or another managed execution system.

Do not disguise managed work as an endless sequence of opaque Short Tasks.

## Canonical transport

Request:

```text
requests/<task_id>/request.json
```

Result:

```text
results/<task_id>/result.json
```

A request write is only dispatch acceptance. It is not execution success.

A workflow start, Runner pickup, Luna acknowledgement, cache file, or stdout alone is not completion.

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

For exact-script requests, preserve the exact execution identity. BAT/CMD work runs through `cmd`; PowerShell work runs through `pwsh`.

## Skills

DoLuna relay turns do not load Skills.

If another AI caller uses this repository for direct-bounded domain work, it may read `skills/index.json` first and load only relevant referenced Skills.

Do not load the entire Skill catalog into a relay turn.

## Privacy and secrets

Do not put credentials, tokens, cookies, passwords, private keys, or provider secrets in request files.

This source repository is public. Real private requests/results should use a private runtime transport/repository.

Commands and stdout/stderr can themselves contain sensitive values. Treat request/result history accordingly.

## Failure behavior

Do not retry by silently changing the payload.

If the exact transport write fails, return the exact error. If a Short Task execution fails, the semantic owner evaluates the durable result and decides the next action.

After two equivalent no-progress execution attempts, change the method at the semantic owner (normally Dot) or surface the blocker.
