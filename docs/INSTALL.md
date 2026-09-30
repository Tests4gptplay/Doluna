# Installation and deployment

DoLuna's source repository is public. Treat source distribution and private execution transport as separate concerns.

## Recommended topology

```text
public DoLuna source
        |
        | copy/deploy
        v
private runtime repository
        |
        +-- requests/
        +-- results/
        +-- .github/workflows/short-task.yml
        |
        v
dedicated cah-shot Runner
```

This avoids committing real private commands, paths, stdout, or stderr to public history.

## Dedicated Windows Runner

Use a separate Runner directory and identity for Short Task work.

Register it with the custom label:

```text
cah-shot
```

Suppress normal default labels when practical.

The workflow intentionally targets:

```yaml
runs-on: cah-shot
```

Use GitHub's current official self-hosted Runner package and a one-time repository registration token. Never commit the token.

## Runtime environment

Configure these outside Git:

```text
SHORT_TASK_CACHE_ROOT=<persistent cache root>
SHORT_TASK_ALLOWED_ROOTS=<semicolon-separated absolute roots>
```

Example only:

```text
SHORT_TASK_CACHE_ROOT=D:\ShortTask\cache
SHORT_TASK_ALLOWED_ROOTS=D:\Projects;D:\ShortTask\work
```

The repository checkout and cache root are automatically allowed.

If `SHORT_TASK_CACHE_ROOT` is absent, v1 falls back to `RUNNER_TEMP\short-task-cache`.

## GitHub Actions permission

The runtime workflow needs permission to commit `results/<task_id>/result.json`.

Do not expose request-write authority to untrusted users: accepted request write access is effectively command authority on the attached Runner within its configured roots.

## Smoke test

Create:

```text
requests/smoke-hello-001/request.json
```

from `examples/hello.request.json`, changing `task_id` to `smoke-hello-001`.

Verify:

1. exactly one Short Task run starts;
2. it lands on the `cah-shot` Runner;
3. `results/smoke-hello-001/result.json` is committed;
4. result status is `succeeded`;
5. exit code is `0`.

Runner online status alone is not acceptance.

## Luna / Work side

The Luna relay should receive only the minimum repository write capability needed for the request surface.

Its semantic contract is in:

- `AGENTS.md`
- `AGENT.md`
- `FOREGROUND.md`
- `adapters/doluna/RELAY_PROMPT.md`

Do not give Luna direct shell credentials merely to implement the relay.
