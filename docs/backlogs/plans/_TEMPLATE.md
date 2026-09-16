<plan>
  <meta>
    <title>{{short descriptive title}}</title>
    <status>not_started</status> <!-- not_started | in_progress | completed -->
  </meta>
  <context>
    <!-- links to any research/debug notes or product doc sections this plan
         depends on -->
  </context>
  <targets>
    <!-- every file this plan may touch, marked (new) where new -->
  </targets>
  <out-of-scope>
    <!-- optional: explicitly excluded work, to prevent scope creep -->
  </out-of-scope>
  <requirements>
    <!-- PLAN-SPECIFIC constraints and contracts only: schemas that are source
         of truth, invariants from architecture.md this comes near, the gates
         that must keep passing. Anything true of every future feature belongs
         in .claude/rules/, not here. -->
  </requirements>
</plan>

# Implementation Phases

## Phase 1 — {{name}}
- [ ] step
- [ ] step

## Phase 2 — {{name}}
- [ ] step

<!--
Usage notes:
- This file is the implementer's contract. It starts cold on a smaller model, so
  anything it needs must be written here — what it may not touch included.
- `goal.xml` sits beside this file: the append-only log of states, navigated
  with scripts/goal.sh. It says what the user wants; this says how to get there.
- Keep <targets> accurate as you go — add files you didn't anticipate.
- Naming convention: docs/backlogs/plans/active/{YYMMDD-HHMM-slug}/, created by
  `scripts/goal.sh new <slug> "<title>"`. Every new plan starts under active/,
  one at a time.
- When complete: tick every checkbox, set <status> to completed, then move the
  folder to done/. If abandoned before completion, move it to archived/ instead.
-->
