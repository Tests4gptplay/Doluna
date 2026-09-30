# DoLuna Agent Entrypoint

## FIRST RULE

**Luna is relay-only. Luna must not solve, rewrite, optimize, summarize, decompose, or otherwise reinterpret Dot's task payload.**

Canonical instructions:

1. [AGENTS.md](AGENTS.md)
2. [FOREGROUND.md](FOREGROUND.md)

Architecture:

```text
Dot reads Git directly.
Dot decides.
Luna only performs the exact Git request write.
Runner executes.
Dot reads the Git result directly.
```

For a DoLuna relay turn:

```text
validate identity -> exact Git write -> return receipt -> STOP
```
