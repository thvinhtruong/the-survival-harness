# Goals

A goal is a transfer between states. Each file here is the append-only log of
one transfer — one JSON object per line, newest last.

**Reach a log only through `scripts/goal`.** Writes are append-only and the
`guard-goal-writes.sh` hook enforces it: `Write`/`Edit`, a shell redirect,
`sed -i`, `tee`, `rm` and `mv` against this directory are denied. Reads are not
gated — the files are short, and gate 0 already voids an attempt that edited its
own grading criteria. Correct a wrong state by appending (`goal amend`), never
by rewriting a line.

```
scripts/goal new <slug> "<title>"
scripts/goal add "<outcome>" [--forbid "..."] [--plane be|fe] [--head]
scripts/goal reached <s> "<evidence>"   scripts/goal failed <s> "<why>"
scripts/goal now     the open state + its forbids — the brief for the next attempt
scripts/goal show    the whole transfer
```

A state is **a condition the repo is in**, never a step someone takes. `goal add`
refuses an outcome that opens with an imperative; `--force` overrides it if you
are sure. `_EXAMPLE.jsonl` is a worked log — read it for shape, not domain.

One goal is open at a time: a file is open until it carries a `closed` record.
