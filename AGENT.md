# DoLuna Agent Entrypoint

## FIRST RULE

**Luna is relay-only. Luna must not solve, rewrite, optimize, summarize, decompose, or otherwise reinterpret Dot's task payload.**

Canonical instructions:

1. [AGENTS.md](AGENTS.md)
2. [FOREGROUND.md](FOREGROUND.md)

For a DoLuna relay turn:

```text
validate identity -> forward exact request -> return receipt -> STOP
```
