# claude-harness-template

A goal-driven Claude Code harness, extracted from a working project. Stack-agnostic.

The idea it encodes: **work is a transfer between states.** Not a task list, not
a backlog — one line saying where the repo stands, one line saying where the user
wants it, and an append-only log of the ones actually reached. The orchestrator
owns the goal and the measurement; a cold implementer owns the code and is never
trusted about whether it worked.

## What's in it

| Piece | What it does |
|---|---|
| `scripts/goal.sh` | The append-only state log. `new`, `add`, `edit`, `get`, `show`. One goal in `active/` at a time. |
| `.claude/skills/cook/` | The procedure: claim the goal → log the states → investigate → write the contract → hand off → measure → read the diff. |
| `.claude/agents/implementer.md` | Codes one plan against its contract. May not edit the goal or the plan. Reports `infeasible` rather than gaming a gate. |
| `docs/backlogs/plans/_TEMPLATE.md` | `plan.md` — `<targets>`, `<out-of-scope>`, `<requirements>`, phases. What makes a cold context safe to delegate to. |
| `.claude/hooks/guard-destructive-ops.sh` | Deterministic deny of destructive shell/SQL/git ops. Runs outside the model, so it cannot be reasoned past. 17-case self-test included. |
| `.claude/hooks/inject-goal-state.sh` | SessionStart: puts the live goal in front of the model. Silent when no goal is active. Survives compaction, which is the point. |
| `.claude/hooks/check-{doc-sync,gap-audit}.sh` | Stop-blocking nudges: contract changed but no doc moved; big implementation with no wiring audit. Both escapable by marker. |

## Install

```bash
./install.sh /path/to/your-repo
```

Never overwrites. An existing `CLAUDE.md` is left alone and the template lands
beside it as `CLAUDE.md.harness-template`.

## Adopt

The entire configuration surface is **one file plus one table**:

- `.claude/harness.conf` — your gates, your contract-bearing paths, your
  gap-audit threshold.
- The Doc map in `CLAUDE.md` — one row per code surface.

Everything else works unmodified.

## The honest caveat

`plan.md`'s contract and the configured gates are what actually stop bad work.
The rest is prose, and prose degrades under context pressure — so a new project
gets real value from this only once it has gates that genuinely fail. Budget for
that first.

Two hooks are deliberately fail-open: an unconfigured `DOC_SYNC_CONTRACT_PATHS`
means the doc-sync hook does nothing rather than blocking every Stop. Missing
`jq` disables all the JSON-parsing hooks the same way. They are nudges, not a
sandbox. `guard-destructive-ops.sh` is the one that is meant to bind, and even
that is a safety net rather than a sandbox — see its `.conf` header.
