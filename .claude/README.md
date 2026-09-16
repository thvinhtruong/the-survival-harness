# .claude/

Claude Code config for this repo.

## Contents

| Path | Purpose |
|------|---------|
| **harness.conf** | The entire per-project configuration surface: the gates, the contract-bearing paths, the gap-audit threshold. Hooks source it at runtime; `cook` reads it before it measures. Adopting the harness means editing this file and the Doc map in `CLAUDE.md` — nothing else. |
| **rules/** | Injected into **every** turn — there is no load-on-demand here, so the only way to unload a rule is to move it out. Holds the behavioural floor and the goal-driven mechanism, nothing procedural — the loop that runs a goal is the `cook` skill, loaded on invoke. |
| **agents/** | Agent definitions, loaded on spawn. `implementer.md` carries the coding standards, since the orchestrator never writes product code. |
| **skills/** | On-demand skill modules loaded by description match. `cook` is the procedure; add stack-specific skills as the project earns them. |
| **hooks/** | The parts that actually bind. `guard-destructive-ops.sh` runs outside the model and cannot be reasoned past; the Stop hooks nudge and are escapable by marker. |
| **state/** | Per-session markers. Gitignored. |

## Repo context

**Canonical engineering context** is in the repo root: **`CLAUDE.md`**. Read that
first for stack, routes and commands. This folder defines how Claude should
behave (protocol) and optional skills.

## Key principles

- **Goal-driven**: a goal is a transfer between states. `docs/backlogs/plans/active/<id>/goal.xml` is the append-only log of them, one line each, beside the `plan.md` that is the implementer's contract. Navigate with `scripts/goal.sh`. "Did it work?" is your reading, not the implementer's claim.
- **Delegate only against a written contract**: `plan.md`'s requirements, targets and out-of-scope are what make a cold Sonnet context safe to trust. Without them, spawning is an agent re-deriving your context — do it inline.
- **Token discipline**: Use the **Doc map** in `CLAUDE.md` to skip irrelevant sections. Conditional content belongs in a skill (loads on invoke) or an agent body (loads on spawn), never in `rules/`.
- **System invariants**: `docs/reference/architecture.md` — the Boundary Map. Edit a rule in place; git is the history.
