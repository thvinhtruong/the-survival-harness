# How to work here

Always loaded. This is behaviour, not procedure — the procedure for building a
feature is the **`cook` skill**.

## 1. Think before coding

State the assumption instead of proceeding on an unclear one. If a request has
two readings that lead to different work, say both and pick one — don't silently
choose. Surface confusion early; a clarifying sentence before the edit is cheaper
than a rewrite after it.

## 2. Simplicity first

Write the least code that satisfies the request. No speculative features, no
premature abstraction, no flexibility nobody asked for.
Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical changes

Edit existing files; never a parallel `*-v2` or `*-enhanced`. Match the
surrounding style. Remove only what *your* change made dead — pre-existing dead
code stays unless removing it was the ask. Comments are a last resort: the code
should speak for itself.

## 4. Load context on demand

Nothing in `docs/reference/` is an always-read. Open `architecture.md` when you
need the overall shape or an invariant, then the one **Doc map** row your task
touches — and only when the code alone is not enough leverage: an unfamiliar
area, a flow you are debugging, a boundary you are crossing. One surface, one
plane, never both.

## 5. Goal-driven: work is a transfer between states

A goal is one transfer: the repo as it stands → the repo as the user wants it.

- A **state** is one line saying what the user wants, in their own words — an
  outcome, never a task list and never a diff. The first one must be true at HEAD
  and the last one is where the repo stands.
- `goal.xml` is the **append-only** log of those states, beside the `plan.md` it
  belongs to in `docs/backlogs/plans/active/<id>/`. `plan.md` is the contract an
  implementer codes against.
- **Reach the log only through `scripts/goal.sh`** (`show`, `get`, `add`,
  `new`, `edit`). Append-only means you correct by adding: `edit` rewords the
  last state; an earlier one that turned out wrong gets a new state saying so.
- `active/` is the status — one folder there at a time, moved to `done/` or
  `archived/` when it closes. Git is the archive; a SessionStart hook puts the
  live log in front of you, so you never go looking for it.
- A state that can only be reached by breaking a downstream rule is a deadlock
  you built, not a goal. Boundary Map wins: a state contradicting
  `docs/reference/architecture.md` is invalid until that invariant is changed
  there, deliberately.

Running the transfer — claiming the goal, investigating, writing the contract,
handing off, measuring — is the **`cook` skill**. Use it for anything bigger than
a local fix.

## 6. Measure, never claim

A gate you did not run is not a gate. The gates in `.claude/harness.conf` are
the evidence; a subagent's report that it worked is not. Never say done with a
failing or unrun gate — name it instead. Green gates are not the same as the
feature working: read the diff.

## 7. Debug to root cause

Read the error, trace the path, form a hypothesis before touching code. Inspect
real behaviour against the running system, not your memory of it. Fix the cause,
not the symptom — and never reach green by editing a test, widening a type to
`any`, adding an ignore pragma, or swallowing an exception.

## 8. Write findings where they are read

`docs/reference/architecture.md` is the Boundary Map — the invariants the code
cannot enforce for itself. A decision that changes one edits that rule **in
place**; the file is the record and git is the history. Research digests go to
`docs/backlogs/research/`, debug notes to `docs/backlogs/debug/`.
