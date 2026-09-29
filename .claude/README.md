# .claude/

Claude Code config for this repo.

## Contents

| Path | Purpose |
|------|---------|
| **harness.conf** | The per-repo values the mechanism runs on: the gates, the files they cover, the contract-bearing paths, the generated files, the gap-audit threshold. `hooks/lib.sh` sources it; `cook` and `debug` read it before they measure. Retuning a hook means editing this, not the hook. |
| **rules/** | Injected into **every** turn — there is no load-on-demand here, so the only way to unload a rule is to move it out. Holds the behavioural floor, nothing procedural — the loop that runs a goal is the `cook` skill, loaded on invoke. |
| **agents/** | Agent definitions, loaded on spawn. `implementer.md` carries the coding standards, since the orchestrator never writes product code. Held to the spawns `cook` §5 and `debug` sanction — a description here costs system-prompt tokens in every session, so an agent that exists is an agent being advertised. |
| **skills/** | Only what a procedure runs or calls by name: `cook` (features), `debug` (bugs), `gap-audit` (wiring + security of the diff), plus any tool skill those call. Every description costs tokens in every session, so advice and pattern skills belong in an unloaded `skills-archive/`, moved back only when a task earns it. |
| **hooks/** | The parts that actually bind. The three `guard-*` hooks run outside the model and cannot be reasoned past; the Stop hooks nudge and are escapable by `scripts/skip.sh` (`log-tokens.sh` only measures — it never blocks). `lib.sh` is sourced, not run. `test-guard.sh` covers all of it — run it after touching any hook. |
| **state/** | Gitignored and disposable. **One file**: `harness.log`, tab-separated and append-only, holding the session baselines, the gate/skip records, the blocks that fired and the per-turn token roll-up. Line shapes are documented at the top of `hooks/lib.sh`. (`implementer-active` is a live flag `cook` toggles, not state.) |

## Repo context

**Canonical engineering context** is in the repo root: **`CLAUDE.md`** — the Doc
map says which doc to read for which surface. This folder defines how Claude
behaves.

## Key principles

- **Evidence, not assertion**: a gate records its own pass from inside the Makefile recipe (`scripts/gate-record.sh`), keyed to a fingerprint of the tree it ran on. So "green" expires the moment you edit again, and `harness.log` tells a gate that passed from a gate that was claimed. The Bash tool result carries no exit code, which is why the recipe records rather than a hook observing.
- **Session scope, not working tree**: the Stop hooks measure `baseline..HEAD` plus the working tree, where the baseline is the commit the session started from. Measuring the working tree alone meant a mid-session commit hid the session's work — the hooks fired on abandoned work and went quiet on finished work.
- **Escape hatches are logged**: `scripts/skip.sh <check> "<reason>"` is one command and the work it skips is ten minutes, so it wins on any given day. Each use is one record line in `harness.log`, counted back at the next session start. A hook that passes writes nothing — a log that says "fine" once per turn buries the lines that matter.
- **Measured, not guessed**: `hooks/log-tokens.sh` reads the session transcript on every Stop and appends the turn's tokens (`calls/out/cw/cr/in`, main vs subagent) to `harness.log`. Deduped by `requestId` — one API call spans several transcript lines carrying the same usage. Do not sum the columns: cache reads are billed at a fraction of input, cache writes at a premium.
- **Goal-driven, no plans** (inside the `cook` and `debug` skills): a goal is a transfer between states. `docs/backlogs/goals/<id>.jsonl` is the append-only log of them, one JSON record per line (`goal`, `state` with its `forbid`s, `failed`, `reached`, `closed`). A bug fix is the same log in a fixed shape — `scripts/goal --debug`, `docs/backlogs/debug/<id>.jsonl`, exactly Reproduced → Fixed → Recorded, and the closed log is the lesson. Write either only with `scripts/goal` — `guard-goal-writes.sh` denies anything else, always. A `failed` record is what stops the next attempt repeating a dead end. "Did it work?" is your reading, not the implementer's claim.
- **Delegate only against stated bounds**: the state's `forbid` lines and the files the handoff names are what make a cold Sonnet context safe to trust. Without them, spawning is an agent re-deriving your context — do it inline.
- **Token discipline**: use the **Doc map** in `CLAUDE.md` to skip irrelevant docs. Conditional content belongs in a skill (loads on invoke) or an agent body (loads on spawn), never in `rules/`.
- **No boundary map**: the `navigator` agent (Haiku) reads the code and cites `path:line`; the main agent opens a citation only to double-check. The only written findings are bug lessons in `docs/backlogs/debug/`.
