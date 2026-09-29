---
name: cook
description: Build a feature end to end under the goal-driven workflow — route context, log the state the user wants, investigate and write the forbids it must respect, hand it to the implementer, then measure until every gate passes. Use when the user types /cook followed by a feature description, or says "cook this", "build this feature", "implement this properly".
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Skill, Agent
---

# cook

`/cook <what to build>` — the standard procedure, so a feature is never a bare
prompt. You own the goal, the investigation and the measurement. You do not
write product code.

A goal is a transfer between states. `docs/backlogs/goals/<id>.jsonl` is the
append-only log of them, one JSON record per line, written only by
`scripts/goal`. **There is no plan file.** The states, their `forbid` lines and
the `failed` records are the whole durable brief; everything else is re-derived
from the code when it is needed. The repo's gates, contract paths and gap-audit
threshold are in `.claude/harness.conf`.

## 1. Scout first — you are the captain, Haiku is the navigator

**You MUST NOT read code or docs at the start.** Classify the request, name the
one **Doc map** row in `CLAUDE.md` it touches — one surface, one plane, never
both — and spawn one `navigator` (Haiku) with:

```
User request: <exact original request>
Doc map row: <the row>
Report short facts, each cited as path:line:
- Files in play, and the production entry point (route, handler, page, CLI) that reaches them
- What the code does today in that area (what is true at HEAD)
- Guards, tests and comments stating a rule the change comes near
- Contracts it crosses: response shapes and their client mirrors, schemas, access rules
- Anything you could not resolve — say so rather than guess
```

Steps 3 and 4 are written from that report. Read for yourself **only on
demand** — when the report is unclear, contradicts itself, leaves a gap you
flagged, or a forbid needs broader context than a report can carry — and then
open only the cited `path:line`, not the area.

## 2. Claim the goal

```bash
scripts/goal now
```

Another goal already open → **stop and ask**. That is live state; an interrupted
goal is not recoverable from intent alone. Otherwise:

```bash
scripts/goal new <slug> "<title>"
```

That creates `docs/backlogs/goals/<id>.jsonl`. One goal is open at a time — a
file stays open until `goal close` writes a `closed` record. **Reach the log only
through `scripts/goal`**: `guard-goal-writes.sh` denies every other write, so
append-only holds even when this instruction has fallen out of context.

## 3. Log the states

A state is one line saying explicitly what the user wants, in their terms — read
off their own words, not translated into tasks. Start with where the repo stands
today, so the transfer has a from:

```bash
scripts/goal add "Check-in submissions are discarded; nothing reaches the API." --head
scripts/goal add "A submission persists and its author can read it back." --plane be \
  --forbid "no new migration — the columns and access rules already exist"
```

- One state, one condition. If it says "and", it is two.
- `--head` marks the state true at HEAD, taken from the scout's report. If the
  report does not establish it, read that one path on demand before logging it.
- Append-only: correct by appending. `goal amend` re-states the last one.
- `goal now` is the open state plus its forbids; that is what the next handoff
  aims at. `goal show` is the whole transfer, failed attempts included.
- `goal add` refuses an outcome that opens with an imperative. If you are
  fighting that check, you are writing a task — rephrase it as a condition.
  `--force` exists for the rare false positive, not as the way through.

### A legal next state

You write the states; the `implementer` is bound by rules you do not carry. A
state it can only reach by breaking one is a deadlock you built.

- **Outcomes, not diffs.** What becomes true — never which lines change or which
  file holds them. Over-specifying that is how a goal turns back into a plan.
- **No state reachable only by a new parallel file.** Edit-don't-duplicate binds
  the implementer; `*-v2` / `*-enhanced` paths are refusals, not work.
- **No state whose cheapest route is weakening a check.** Editing a test,
  widening to `any`, `# type: ignore`, swallowing an exception — all forbidden
  downstream. If the state is only reachable that way, it is the wrong state.

## 4. Write the forbids from the scout's report

This step is yours and it is the one the implementer cannot do — it starts cold
on a smaller model. The scout found the facts; the judgment is yours. Work from
its report, reading code only on demand (§1) where the report is not enough to
decide. What this step has to produce is two things, and neither is a file:

- **`forbid` lines on the state** — what this goal must not touch, and why. This
  is the part nothing else can re-derive: which files to open is a grep, but
  *"no staff read path — widening it here crosses a consent boundary this goal has
  not cleared"* is a judgment, and it is what stops a rewrite. Write it with
  `goal add --forbid`; a boundary learned late (typically from a failed attempt)
  is a fresh state carrying it, so the next attempt sees when it was added.
- **The map** — which files the change touches, which production entry
  point reaches them, which guarded rules it comes near. It comes from the scout's report and is not stored: it goes in the
  handoff message, never in a file that is stale by the next goal.

If you cannot name the files the change touches, the investigation is not
finished — send the scout back with the specific gap, or read that path on
demand. Handing over an unbounded goal is how a cold implementer invents
architecture.

## 5. Hand off

Spawn `implementer` (Sonnet, fresh context). It starts cold — include all of:

```
User request: <exact original request>
Target state: scripts/goal now — the open state and the forbids it must respect
State log: scripts/goal show — what has been transferred, and every ✗ approach not to repeat
Files in play: <the map from §4 — the navigator's path:line citations, plus the entry point that reaches them>
Gates it must keep passing: <GATES from .claude/harness.conf, as make targets>
Decisions already made: <confirmed choices>
Already tried: <what earlier attempts did and why it failed>
Working directory: <repo root>
```

Arm the guard around the grading criteria before you spawn, and clear it after:

```bash
touch .claude/state/implementer-active     # before the spawn
rm -f .claude/state/implementer-active      # after it returns
```

While that marker exists, a write to a goal or debug log (`docs/backlogs/goals/`,
`docs/backlogs/debug/*.jsonl`) or to `scripts/goal` is denied outright rather than caught by gate 1 after the attempt
is spent.

Spawn it only once `goal now` carries its forbids and you can name the files in
play. If not, the investigation is not finished: close the gap per §4.

Parallel spawns only across the repo's one genuinely disjoint split (typically
backend ∥ frontend); `--plane be|fe` on a state marks which
side it falls on. Never chain investigate → implement → review.

Also justified: the §1 `navigator` (required, not optional), `researcher` for web-only external sources (never the repo — that is `navigator`),
and `navigator` again for bulky evidence (large logs, CI runs, DB state) — work
whose bulk output you don't want to keep. Never spawn for review or docs.

## 6. Measure

Gates in this order — gate 1, then `GATES` from `.claude/harness.conf`. First
failure ends the attempt.

```bash
git diff --name-only   # 1. did it touch the goal log or scripts/goal?
make <gate>            # 2…n. each target in GATES (.claude/harness.conf), in order
```

Each gate records its own pass against a fingerprint of the tree it ran on, so
run them **after** the final edit: an edit afterwards lapses the evidence. If a
gate genuinely cannot run here, name it and why in the report rather than
staying quiet.

Gate 1 first and always: an attempt that edited its own grading criteria is void
regardless of what else passes. The implementer's claims about success are
**ignored** — only your own reading counts.

State reached → `goal reached <s> "<what you observed>"`, and the log now
carries the transfer. Not reached → `goal failed <s> "<why>"` in those exact
words, then hand off again; the next attempt reads that record and does not
repeat it. Three attempts without progress → stop and report. Do not raise your
own budget; the cap exists to turn a silent loop into a visible decision.

If the implementer returns `infeasible`, it is telling you the goal is wrong.
`state_unreachable` and `scope_too_narrow` are the only cases where you may
restate it — and then you append a state saying what changed and why, so the
relaxation is on the record. A goal that quietly relaxes until it passes is the
same failure as an implementer editing tests, just slower.

## 7. Read the diff

Only once the gates are green. Green gates are not the same as the feature
working, and this is the only thing standing in front of green-but-wrong:

- Does it reach the state, or satisfy the letter of it by a route that misses
  the point?
- Every `forbid` on the state — respected, including the ones no command checks?
- Dead code, swallowed exceptions, a TODO where the hard part was, a value
  hardcoded to make a check pass?

A failed read is a failed attempt. Be specific about what to change.

## 8. Browser pass — UI changes only, not optional

Unit tests cover logic, not rendering, and a green build says nothing about what
appeared on screen. If `BROWSER_VERIFY_SKILL` in `.claude/harness.conf` is set,
invoke it and look at the change. Unset, say in the report that nothing was
looked at.

## 9. Gap audit

Invoke `gap-audit` for anything multi-file — it catches code that compiles,
passes tests, and is never reached. The Stop hook blocks at 5+ changed code
files anyway.

## 10. Docs

**Only a breaking change earns a docs edit** — a response shape, a schema or
access-control decision, a route or layout owner, a design token or component spec. Then
update the Doc map's "Update when it breaks" column for the area touched, and
keep client mirrors in lockstep with the shapes they mirror. A bug whose
root cause could recur gets a lesson in `docs/backlogs/debug/`.

Nothing broke — a behaviour-preserving refactor, a doc-only edit, a trivial fix,
a revert, a dependency bump — means no doc changes. Write the marker so the
Stop hook stops nudging:

```bash
scripts/skip.sh doc-sync "<reason nothing broke>"
```

It is keyed to the current tree, not to a session id the shell cannot expand, and
it is logged — the count comes back at the next session start.

"I'll do the docs later" is not the same as "nothing broke", and does not justify
the marker.

## 11. Close and report

```bash
scripts/goal close "<what shipped, or why it was dropped>"
```

Then report: the state trajectory, attempt by attempt; what you skipped and why;
what still needs a human. Never report done with a failing or unrun gate — name
it.

---

**What this skill can and cannot do:** the state's `forbid` lines, the write
guard and the Makefile gates are what actually stop bad work. Everything else
here is instructions, and instructions degrade under context pressure. If you
want a step to be truly binding, make it a gate or a hook, not a sentence.
