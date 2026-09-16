# Architecture — the Boundary Map

The invariants the code cannot enforce for itself. A decision that changes one
edits that rule **in place**; this file is the record and git is the history.

A `cook` state that contradicts something here is invalid until the invariant is
changed here first, deliberately. An implementer whose change needs a rule here
to bend reports `infeasible`.

Keep §1–2 short enough that a cold implementer reads them in full — that is the
priority read named in `.claude/agents/implementer.md`.

## 1. Invariants

<!-- Rules that must hold no matter what. One line each, with the "why" beside
     it. Examples of the shape:
     - No raw user PII in logs that leave the process.
     - The generated client mirrors server schemas by hand; they move together.
     - Money is integer minor units end to end; no floats cross a boundary. -->

## 2. Domain nouns

<!-- The vocabulary. If two parts of the codebase call the same thing different
     names, fix it here first. -->

## 3. Boundaries

<!-- What may depend on what. The disjoint splits, if any — cook §5 allows
     parallel spawns only across one of these. -->

## 4. Stack & deploy

<!-- How it builds, runs and ships. -->
