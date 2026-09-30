# DoLuna Agent Contract

DoLuna is a small bridge between Dot and a Short Task Runner.

## Architecture

```text
READ
Dot -> Git state / results -> Dot

WRITE / EXECUTE
Dot
 -> builds the complete request
 -> Luna Work relay
 -> requests/<task_id>/request.json
 -> .github/workflows/short-task.yml
 -> cah-shot
 -> runner/execute_request.ps1
 -> results/<task_id>/result.json
 -> Git
 -> Dot reads the result
```

## Roles

### Dot

Dot is the semantic owner.

Dot reads the relevant Git state directly, decides what should happen, builds the complete Short Task request, and later reads the result directly from Git.

### Luna

Luna is the write relay.

Luna receives a complete request from Dot and writes it to the requested Git path. Luna does not need project context beyond what is required to perform that write.

### Short Task Runner

The Runner executes the request and writes the durable result.

## Canonical files

- `FOREGROUND.md` — Luna relay behavior.
- `docs/PROTOCOL.md` — request/result protocol.
- `schema/request.schema.json` — request shape.
- `.github/workflows/short-task.yml` — Git-to-Runner dispatch.
- `runner/execute_request.ps1` — Windows executor.
- `requests/<task_id>/request.json` — task request.
- `results/<task_id>/result.json` — task result.

## State flow

```text
Dot reads state
 -> Dot creates request
 -> Luna writes request
 -> Runner executes
 -> result is written
 -> Dot reads result
 -> Dot decides next action
```

A request write means the task was dispatched. The result file carries the execution outcome.
