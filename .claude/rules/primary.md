# How to work here

1. **Think before coding** — when a request has two readings, state both and pick one out loud rather than silently choosing.
2. **Simplicity first** — write the least code that satisfies the request; no speculative features or abstractions.
3. **Surgical changes** — edit existing files in their style, never a parallel `*-v2`, and remove only what your own change made dead.
4. **Context on demand** — ask the `navigator` agent (Haiku) first, and open its `path:line` citations only when you need to double-check.
5. **Goal-driven work** — a bug goes through the `debug` skill; a feature, or a fix that outgrew one, goes through the `cook` skill, which owns the goal log.
6. **Measure, never claim** — run every gate in `GATES` (`.claude/harness.conf`) after the last edit, and never say done with a failing or unrun gate.
7. **Debug to root cause** — fix the cause, never reach green by editing a test, widening to `any`, an ignore pragma, or swallowing an exception.
8. **Write down only what prevents a repeat** — a bug's root cause or a lesson learnt goes in `docs/backlogs/debug/`; nothing else gets written up.
