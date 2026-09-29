---
name: debug
description: Fix a bug end to end as a three-state debug log — Reproduced → Fixed → Recorded — reading the code yourself to the root cause, fixing inline (or handing a 6+ file fix to the Sonnet implementer), measuring until every gate passes, and closing on the lesson. Use when the user types /debug followed by a bug, error or failing behaviour, or says "fix this bug", "debug this", "why is X broken".
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Skill, Agent, AskUserQuestion
---

# debug

`/debug <what is broken>` — the standard procedure for a bug, so a fix is never
a guess. You own the root cause and the measurement; you write the fix unless it
spans more than 5 files.

A bug fix is goal-driven like `cook`, in a fixed shape. `scripts/goal --debug`
keeps an append-only log in `docs/backlogs/debug/<id>.jsonl` of **exactly three
states, strictly in order** — each reached before the next is logged:

| S | Opens with | True when |
|---|---|---|
| 1 | `Reproduced:` | the bug fails in front of you (a test, or a recorded repro) and the root cause is named at `path:line` |
| 2 | `Fixed:` | the repro passes, the cause is gone (not hidden), and every gate is green |
| 3 | `Recorded:` | the lesson — what to do or never do again — is stated |

The script refuses a fourth state, a wrong label, or a state logged before the
previous one is reached. **The finished log is the lesson**: its title is the
symptom, S1 carries the cause, S2's `failed` records are the plausible fixes
that did not work, S3 is what to remember. There is no separate lesson file.

Write every outcome in the bug's own words — a condition that is true or false,
never a step. Gates and the gap-audit threshold are in `.claude/harness.conf`.

## 1. Lessons first

Search `docs/backlogs/debug/` — the `.jsonl` logs and the older `.md` lessons —
for the symptom, the module and the error text before anything else:

```bash
grep -ril "<error text | module | table>" docs/backlogs/debug/
```

A matching lesson is the first hypothesis — and often the recorded
"plausible fix that does not work". Read only the matching file.

## 2. Open the log

```bash
scripts/goal --debug now
```

Another debug log open → **stop and ask**; it is live state. An open `cook`
goal is fine — bugs surface mid-goal, and the two logs are independent.
Otherwise open one, titled with the symptom as the user would say it:

```bash
scripts/goal --debug new <slug> "<the symptom, in the user's words>"
```

Reach the log only through `scripts/goal --debug` — `guard-goal-writes.sh`
denies every other write.

## 3. S1 — Reproduced

**Evidence before theory.** Get the failure in front of you, in its exact words:

- a failing test, run alone (the single test file, `-x` / fail-fast),
- the traceback / console / network error,
- or the running app via `BROWSER_VERIFY_SKILL` (`.claude/harness.conf`) for anything visual.

Can't reproduce → say so and ask for the missing input (steps, data, env);
don't fix what you haven't seen. Shrink it: the smallest input or step that
still triggers it, and whether it holds in every environment (local vs container,
anonymous vs signed-in). Evidence too bulky to hold in context (large logs, CI
runs, DB state) → spawn `navigator` to read it and keep only its cited facts.

**Then read the code yourself** — the step `cook` delegates and `debug` does
not. Start at the entry point the symptom reaches — the route handler for an
API bug, the page's route for a UI bug — and follow the call chain to where
actual diverges from expected. Read the files on that chain, not the area around
it. Grep a generated reference for the one entry you need (routes: the
`api-lookup` skill, when `API_SPEC` is set); never read it whole. Ask what changed before what's wrong: `git log --oneline -20 -- <path>`,
`git bisect` when it used to work. Temporary logging is fine to confirm a
hypothesis — remove it before S2, and never log user PII or secrets.

When the cause hinges on something outside the repo — a library's behaviour, a
vendor API, a spec, a known upstream bug — spawn
`researcher` with the exact question and the versions in play
(from the lockfiles / manifests). Web only.

**Name the root cause** in one or two sentences: *what* is wrong, *where*
(`path:line`), *why* it produces the symptom. If you can't say why, you have a
correlation — keep reading. Ask "why?" until it lands on something you can
change; the first answer is usually the symptom's location, not its cause.

```bash
scripts/goal --debug add "Reproduced: <repro> fails because <cause> at <path:line>"
scripts/goal --debug reached 1 "<the failing output you saw>"
```

## 4. Size the fix — then pick the route

Count the files the fix has to touch (tests included):

| Scope | Route |
|---|---|
| **≤ 5 files** | Fix it yourself, §5. |
| **> 5 files** | Hand off to `implementer` (Sonnet), §6. |
| **Too large** — see below | **Stop. Ask the user** to confirm switching to `/cook`. |

**Too large** means the "fix" has become a feature: a new migration, table or
access policy; a response shape change on both planes; a new route, page or
module; a redesign of the flow rather than a correction to it; or more than
~10 files. Use `AskUserQuestion` with the root cause, the files you'd touch and
why it outgrew a fix — options *switch to /cook* (recommended) / *narrow fix
only* / *stop here*. On *cook*: `scripts/goal --debug close "escalated → cook: <why>"`,
then invoke the `cook` skill with the original request plus your root cause;
your S1 stands in for its scout. Never start a cook goal without that
confirmation.

Then log S2 — the outcome, never the diff — with a `--forbid` for anything the
fix must not touch:

```bash
scripts/goal --debug add "Fixed: <repro> passes and <the cause> no longer holds" \
  --forbid "<what it must not touch, and why>"
```

## 5. Fix inline (≤ 5 files)

- A regression test first where one is feasible — it fails on the bug, passes
  on the fix. Add a test; never edit an existing one to go green.
- Smallest change that removes the cause, in the file's own style. A guard that
  hides the symptom is not a fix (`primary.md` §7).
- A response shape change moves its client mirror in the same change.
- Grep for the same pattern elsewhere — a bug in one caller is often in its
  siblings. Fix those only if they're inside §4's size; otherwise list them.

## 6. Hand off (> 5 files)

Spawn `implementer` (Sonnet, fresh context). It starts cold — include all of:

```
Spawned by: debug skill
User request: <exact original request>
Target state: scripts/goal --debug now — S2 and the forbids it must respect
State log: scripts/goal --debug show — the root cause (S1) and every ✗ approach not to repeat
Files in play: <every file, with the path:line you read in §3>
Regression test: <the failing test to add, or why none is feasible>
Gates it must keep passing: <GATES from .claude/harness.conf, as make targets>
Working directory: <repo root>
```

Arm the guard as `cook` §5 does — `touch .claude/state/implementer-active`
before, `rm -f .claude/state/implementer-active` after. Its claims of success
are ignored; §7 is the verdict. `infeasible` back from it → reassess §4, most
likely it is a cook-sized change.

## 7. Measure — the S2 verdict

After the last edit, in order — first failure ends the attempt:

```bash
git diff --name-only   # 1. did it touch docs/backlogs/{goals,debug}/*.jsonl or scripts/goal?
make <gate>            # 2…n. each target in GATES (.claude/harness.conf), in order
```

Then re-run the S1 reproduction and watch it pass, and exercise the
neighbouring behaviour the fix could have broken — green gates are not the bug
being gone. UI fix → `BROWSER_VERIFY_SKILL`, look at it. 5+ code files changed →
`gap-audit`. A gate that genuinely can't run → name it and why in the report.

- Reached → `scripts/goal --debug reached 2 "<gates + the repro, now passing>"`.
- Not reached → `scripts/goal --debug failed 2 "<why>"`, in those exact words,
  then fix again or hand off again; the next attempt reads that record and does
  not repeat it. **Three failed attempts → stop and report.**

## 8. S3 — Recorded

The lesson, in one line: what to do, or never do, so this does not happen
twice — the rule, not the story.

```bash
scripts/goal --debug add "Recorded: <the rule this bug teaches>"
scripts/goal --debug reached 3 "<where it applies: module / pattern / table>"
scripts/goal --debug close "fixed"
```

`close` refuses while S3 is unreached, unless the disposition starts
`escalated` or `dropped`. If a contract broke (response shape, schema, access
rule, visual spec) → also the Doc map's "Update when it breaks" column, as `cook` §10.
Otherwise, if a contract-bearing path changed →
`scripts/skip.sh doc-sync "<reason>"`.

## Anti-patterns

- **Random changes** — "maybe if I change this…" without a hypothesis.
- **Ignoring evidence** — "that can't be the cause" when the trace says it is.
- **Assuming** — "it must be X" without having seen X happen.
- **Fixing blind** — logging S2 before S1 is reached (the script refuses it).
- **Stopping at the symptom** — a null check where the null came from upstream.

## 9. Report

`scripts/goal --debug show`, then: root cause (`path:line`), what changed, the
reproduction before/after, gates run, what you skipped and why. Never report
fixed with a failing or unrun gate, or a reproduction you didn't re-run.
