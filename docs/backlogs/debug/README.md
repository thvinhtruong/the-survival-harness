# Debug Logs & Lessons

The only written findings in this repo: a bug's root cause and the lesson that
stops it happening twice. `grep -ril` here before debugging anything.

**Lessons are debug logs** — `<id>.jsonl`, written only by
`scripts/goal --debug` (the `debug` skill), in exactly three states:

```
S1  Reproduced: <repro> fails because <cause> at <path:line>
S2  Fixed: <repro> passes and <the cause> no longer holds     ✗ lines = fixes that did not work
S3  Recorded: <the rule this bug teaches>
```

The title is the symptom, so the closed log is the lesson; there is no separate
file to write. Direct writes to `*.jsonl` here are denied by
`guard-goal-writes.sh`.
