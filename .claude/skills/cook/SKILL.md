---
name: cook
description: Build a feature end to end under the goal-driven workflow — route context, log the state the user wants, investigate and write the plan, hand it to the implementer as a contract, then measure until every gate passes. Use when the user types /cook followed by a feature description, or says "cook this", "build this feature", "implement this properly".
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Skill, Agent
---

# cook

`/cook <what to build>` — the standard procedure, so a feature is never a bare
prompt. You own the goal, the investigation and the measurement. You do not
write product code.

A goal is a transfer between states. `goal.xml` is the append-only log of them,
one line each, beside the `plan.md` it belongs to.

## 1. Route the context

Classify the request. Reference docs are **on demand, not by default**: read
`docs/reference/architecture.md` first when you need the overall shape or an
invariant, then exactly the **Doc map** row in `CLAUDE.md` the request touches —
one surface, one plane, never both — and only when the code alone will not give
you enough leverage (unfamiliar area, a flow you are debugging, a boundary the
change crosses). Never read `done/` or `archived/` plans.

## 2. Claim the goal

```bash
scripts/goal.sh show
```

Another goal already in `active/` → **stop and ask**. That is live state; an
interrupted goal is not recoverable from intent alone. Otherwise:

```bash
scripts/goal.sh new <slug> "<title>"
```

That creates `docs/backlogs/plans/active/<id>/` — `goal.xml` (the state log)
beside `plan.md` (the contract). `active/` is the status: one folder there at a
time, moved to `done/` or `archived/` when it closes. **Reach the log only
through `scripts/goal.sh`** — it escapes the text once, on one line, so `get` is
a `tail`.

## 3. Log the states

A state is one line saying explicitly what the user wants, in their terms — read
off their own words, not translated into tasks. Start with where the repo stands
today, so the transfer has a from:

```bash
scripts/goal.sh add "Check-in submissions are discarded; nothing reaches the API."
scripts/goal.sh add "A submission persists and its author can read it back."
```

- One state, one condition. If it says "and", it is two.
- The first state must be **true at HEAD**. If it is not, you have not read the
  code yet — go to step 4 and come back.
- Append-only: correct by adding. `goal.sh edit` rewords only the last line.
- `goal.sh get` is the current state; that is what the next handoff aims at.

### A legal next state

You write the states; the `implementer` is bound by rules you do not carry. A
state it can only reach by breaking one is a deadlock you built.

- **Outcomes, not diffs.** What becomes true — never which lines change or which
  file holds them. Over-specifying that is how a goal turns back into a spec.
- **No state reachable only by a new parallel file.** Edit-don't-duplicate binds
  the implementer; `*-v2` / `*-enhanced` paths are refusals, not work.
- **No state whose cheapest route is weakening a check.** Editing a test,
  widening to `any`, an ignore pragma, swallowing an exception — all forbidden
  downstream. If the state is only reachable that way, it is the wrong state.
- **Boundary Map wins.** A state contradicting `docs/reference/architecture.md`
  is invalid; change the invariant there first, deliberately, or drop the goal.

## 4. Investigate, then write the contract

This step is yours and it is the one the implementer cannot do — it starts cold
on a smaller model. Read the code, trace the paths, check the contracts, then
write `plan.md` so that everything needed is on the page:

- `<context>` — the research/debug notes and product sections this rests on.
- `<targets>` — every file the change may touch, marked `(new)` where new.
- `<out-of-scope>` — what it must not touch. This is what stops a rewrite.
- `<requirements>` — the constraints and contracts binding *this* change:
  schemas that are source of truth, invariants from `architecture.md` it comes
  near, gates that must keep passing. Anything true of every feature belongs
  in `.claude/rules/`, not here.
- **Phases** — ordered steps with checkboxes.

If you cannot write `<targets>` yet, the investigation is not finished. Handing
over an underspecified plan is how a cold implementer invents architecture.

## 5. Hand off

Spawn `implementer` (Sonnet, fresh context). It starts cold — include all of:

```
User request: <exact original request>
Contract: docs/backlogs/plans/active/<id>/plan.md — read it first, it is complete
State log: scripts/goal.sh show
Target state: <the state this attempt must reach>
Constraints: docs/reference/architecture.md (Boundary Map) — the implementer reads §1-2 itself
Doc map row: <the one row from CLAUDE.md this task touches — name it; the implementer loads that row's docs up front>
Gates it must keep passing: <the GATES from .claude/harness.conf>
Decisions already made: <confirmed choices>
Already tried: <what earlier attempts did and why it failed>
Working directory: <absolute path to the repo root>
```

Spawn it only once `plan.md` is a contract it can code against — constraints,
targets, out-of-scope, phases, and the rules its change must not break. If the
plan is not yet that, the investigation is not finished: do it inline.

Parallel spawns only across a genuinely disjoint boundary in this repo — if you
cannot name one, there isn't one. Never chain plan → implement → review.

Also justified: `researcher` for external docs, `debugger` for large logs,
`git-manager` for commits — work whose bulk output you don't want to keep. Never
spawn for planning, review, or docs.

## 6. Measure

```bash
cat .claude/harness.conf      # the gates for this repo, in order
```

Gate 0, always first:

```bash
git diff --name-only   # did it touch the plan, the log, or scripts/goal.sh?
```

An attempt that edited its own grading criteria is void regardless of what else
passes. Then run each command in `GATES` in order; the first failure ends the
attempt. The implementer's claims about success are **ignored** — only your own
reading counts.

State reached → `goal.sh add` it, and the log now carries the transfer. Not
reached → say exactly what failed, in those words, and hand off again. Three
attempts without progress → stop and report. Do not raise your own budget; the
cap exists to turn a silent loop into a visible decision.

If the implementer returns `infeasible`, it is telling you the plan is wrong.
`state_unreachable` and `scope_too_narrow` are the only cases where you may
restate the goal — and then you append a state saying what changed and why, so
the relaxation is on the record. A goal that quietly relaxes until it passes is
the same failure as an implementer editing tests, just slower.

## 7. Read the diff

Only once the gates are green. Green gates are not the same as the feature
working, and this is the only thing standing in front of green-but-wrong:

- Does it reach the state, or satisfy the letter of it by a route that misses
  the point?
- Every `plan.md` requirement — met, including the ones no command checks?
- Dead code, swallowed exceptions, a TODO where the hard part was, a value
  hardcoded to make a check pass?

A failed read is a failed attempt. Be specific about what to change.

## 8. Browser pass — when the repo has a UI

If `BROWSER_VERIFY_SKILL` in `.claude/harness.conf` is set, invoke that skill
and look at the result. A green build says nothing about what rendered, and
unless a gate actually runs component tests, nothing else in this procedure
will catch a UI that compiles and looks wrong.

Empty value → skip this step; the repo has no UI to look at.

## 9. Gap audit

Invoke `post-plan-gap-audit` for anything multi-file — it catches code that
compiles, passes tests, and is never reached. The Stop hook blocks past
`GAP_AUDIT_THRESHOLD` changed code files anyway.

## 10. Docs

**Only a breaking change earns a docs edit** — a response shape, a schema or
access-control decision, an invariant, a route or layout owner, a design token
or component spec. Then update the Doc map's "Update when it breaks" column for
the area touched. A changed invariant is edited **in place** in
`docs/reference/architecture.md` — no ADR.

Tick `plan.md`'s phases, set its `<status>` to `completed`, then move the folder
from `active/` to `done/`.

Nothing broke — a behaviour-preserving refactor, a doc-only edit, a trivial fix,
a revert, a dependency bump — means no doc changes. Write the marker so the
Stop hook stops nudging:

```bash
mkdir -p .claude/state && echo 'skipped: <reason>' > .claude/state/doc-sync-$SESSION_ID
```

"I'll do the docs later" is not the same as "nothing broke", and does not justify
the marker.

## 11. Report

The state trajectory, attempt by attempt; what you skipped and why; what still
needs a human. Never report done with a failing or unrun gate — name it.

---

**What this skill can and cannot do:** `plan.md`'s contract and the configured
gates are what actually stop bad work. Everything else here is instructions, and
instructions degrade under context pressure. If you want a step to be truly
binding, make it a gate or a hook, not a sentence.
