# DoLuna Agent Entrypoint

Read:

1. [AGENTS.md](AGENTS.md)
2. [FOREGROUND.md](FOREGROUND.md)

Core flow:

```text
Dot reads Git
-> Dot decides and produces the complete request file content
-> Luna copies that content to Git
-> Runner executes
-> Dot reads result
```
