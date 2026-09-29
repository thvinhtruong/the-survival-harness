# claude-harness-template

A goal-driven Claude Code harness, extracted from a working project. Stack-agnostic.

The idea it encodes: **work is a transfer between states.** Not a task list, not
a plan file — one line saying where the repo stands, one line saying where the
user wants it, and an append-only log of the ones actually reached, with the
approaches that failed. The orchestrator owns the goal and the measurement; a
cold implementer owns the code and is never trusted about whether it worked.
And "it worked" is **evidence recorded by the gate itself**, against the exact
tree it ran on — not a claim.

## What's in it

| Piece | What it does |
|---|---|
| `scripts/goal` | The append-only state log, `docs/backlogs/goals/<id>.jsonl` (`--debug`: the fixed three-state bug log in `docs/backlogs/debug/`). `new`, `add` (with `--forbid`), `reached`, `failed`, `amend`, `close`, `now`, `show`. Refuses a state phrased as a task. One goal open at a time. |
| `scripts/gate-record.sh` | Last line of each Makefile gate recipe: records the pass keyed to a fingerprint of the tree in `harness.log`. Also the single definition of that fingerprint, which `skip.sh` records key to. |
| `scripts/skip.sh` | The escape hatch for the Stop hooks — one logged line, keyed to the tree, counted back at the next session start. |
| `.claude/skills/cook/` | Features: scout (navigator) → claim the goal → log the states → write the forbids → hand off → measure → read the diff → gap audit → docs → close. |
| `.claude/skills/debug/` | Bugs, as a three-state log (`scripts/goal --debug`, `docs/backlogs/debug/`): **Reproduced** (root cause at `path:line`) → **Fixed** (gates green; ✗ records are fixes that failed) → **Recorded** (the lesson). The closed log is the lesson. Fixes ≤ 5 files inline, else hands off to the implementer; escalates to `cook` only with the user's say-so. |
| `.claude/skills/gap-audit/` | Seven gap classes that pass unit tests and break production: unwired code, divergent helpers, bypassed filters, starved windows, format mismatches, untested seams — and security at the new seams (access control, injection, fail-open, secrets/PII, disabled safety, new dependencies). |
| `.claude/skills/{verify,api-lookup}/` | Opt-in, shipped as `SKILL.md.template` so they cost no tokens until adopted. `verify`: an outline for the browser pass (`BROWSER_VERIFY_SKILL`). `api-lookup`: queries a generated OpenAPI 3 spec (`API_SPEC`) one route at a time instead of reading it whole. |
| `.claude/agents/` | `navigator` (Haiku, read-only, cites `path:line`), `implementer` (Sonnet, codes one state against its forbids, may report `infeasible`), `researcher` (Haiku, web only). The implementer is the only agent that writes code, for both `cook` and `debug`; the navigator also reads bulky evidence (logs, CI, DB). |
| `.claude/hooks/guard-destructive-ops.sh` | Deterministic deny of destructive shell/SQL/git ops — including `git checkout <path>` / `git restore`. Runs outside the model. |
| `.claude/hooks/guard-goal-writes.sh` | The goal log is append-only as a property of the system: Edit/Write, redirects, `sed -i`, `mv`, `rm`… on it are denied. Always on. |
| `.claude/hooks/guard-protected-paths.sh` | Denies hand-edits to `GENERATED_FILES`, and — while an implementer runs — to the goal log and `scripts/goal`. |
| `.claude/hooks/inject-goal-{state,current}.sh` | SessionStart: records the session baseline, prints the open goal and recent skip count. UserPromptSubmit: one line with the open state, so it survives compaction. |
| `.claude/hooks/check-{doc-sync,gap-audit}.sh` | Stop hooks, scoped to the session (`baseline..HEAD` + working tree): contract changed but no doc moved; big change with no wiring audit. |
| `.claude/hooks/log-tokens.sh` | Per-turn token roll-up (main vs subagent), deduped by `requestId`, into `.claude/state/harness.log`. |
| `.claude/hooks/test-guard.sh` | Syntax sweep of every hook + allow/deny cases for all three guards. Run after touching any hook. |

## Install

```bash
./install.sh /path/to/your-repo
```

Or skip the manual steps below: paste [`SETUP-PROMPT.md`](SETUP-PROMPT.md) into
Claude Code at the target repo's root. It installs, reads the repo, and fills
every setting from the project's own CI and manifests.

Never overwrites. An existing `CLAUDE.md` is left alone and the template lands
beside it as `CLAUDE.md.harness-template`. Requires `git` and `jq`.

## Adopt

The entire configuration surface is **one file, one Makefile convention and one table**:

- `.claude/harness.conf` — your gates (make targets), your contract-bearing paths, your generated files, your gap-audit threshold,
  and optionally a browser-verify skill.
- Each gate recipe in the `Makefile` ends with `@scripts/gate-record.sh <target>`:

  ```make
  test:
  	<your test command(s)>
  	@scripts/gate-record.sh test
  ```

- The Doc map in `CLAUDE.md` — one row per code surface.

Everything else works unmodified.

## The honest caveat

The state's `forbid` lines, the guards and the gates are what actually stop bad
work. The rest is prose, and prose degrades under context pressure — so a new
project gets real value from this only once it has gates that genuinely fail.
Budget for that first.

The Stop hooks are deliberately fail-open: an unconfigured
`DOC_SYNC_CONTRACT_PATHS` means the doc-sync hook does nothing rather than
blocking every Stop, and missing `jq` disables every JSON-parsing hook the same
way. They are nudges, not a sandbox. The `guard-*` hooks are the ones meant to
bind, and even they are a safety net rather than a sandbox — see the header of
`destructive-patterns.conf`.
