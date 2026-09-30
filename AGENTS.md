# DoLuna Agent Contract

DoLuna is a small bridge between Dot and a Short Task Runner.

## Architecture

```text
READ
Dot -> Git state / results -> Dot

WRITE / EXECUTE
Dot
 -> decides the task
 -> produces the complete request file content
 -> Luna Work relay
 -> copies that exact content to:
    requests/<task_id>/request.json
 -> .github/workflows/short-task.yml
 -> cah-shot
 -> runner/execute_request.ps1
 -> results/<task_id>/result.json
 -> Git
 -> Dot reads the result
```

## Roles

### Dot

Dot is the semantic owner and request author.

Dot reads the relevant Git state directly, decides what should happen, and produces the complete contents of the Short Task request file.

Dot later reads the result directly from Git.

### Luna

Luna is only a copy/write relay.

Luna receives:
- the target repository;
- branch;
- request path;
- the complete request file content already authored by Dot.

Luna copies that supplied content to the specified Git path and returns the write receipt.

Luna does not construct request fields or fill in missing task content.

### Short Task Runner

The Runner executes the request and writes the durable result.

## Canonical files

- `FOREGROUND.md` — Luna relay behavior.
- `docs/PROTOCOL.md` — request/result protocol.
- `schema/request.schema.json` — request shape used by Dot.
- `.github/workflows/short-task.yml` — Git-to-Runner dispatch.
- `runner/execute_request.ps1` — Windows executor.
- `requests/<task_id>/request.json` — Dot-authored task request.
- `results/<task_id>/result.json` — task result.

## State flow

```text
Dot reads state
 -> Dot creates complete request content
 -> Luna copies it into Git
 -> Runner executes
 -> result is written
 -> Dot reads result
 -> Dot decides next action
```

A request write means the task was dispatched. The result file carries the execution outcome.
