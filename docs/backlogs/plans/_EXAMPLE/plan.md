<!-- WORKED EXAMPLE — verbatim from the project this harness was extracted
     from. Its paths, skills (`api-lookup`) and domain nouns (circles, mentors,
     consent, RLS) do not exist in your repo and are not meant to.

     Read it for SHAPE, not content: how concrete <targets> get, how <out-of-scope>
     names things it would have been natural to touch and forbids them by reason,
     how <requirements> cites invariants by file and line. That specificity is the
     whole reason a cold implementer can be trusted with it. Delete this folder
     once your own done/ has a better example. -->

<plan>
  <meta>
    <title>Check-in submissions persist and are readable by role</title>
    <status>in_progress</status> <!-- not_started | in_progress | completed -->
  </meta>
  <context>
    - docs/reference/architecture.md §2 — mentor scoping (line 98), anonymity must be
      unjoinable (line 128), no client write policies (line 65)
    - docs/reference/architecture-data-contracts.md — the three consents; `consent_state`
      is consent to *sharing*, not to collection
    - product/v2/ §check-in — what a student may see of their own history
    - `POST /api/submissions` already exists and files correctly; this goal adds
      only the read side. See `backend/app/services/submission_filing.py`.
  </context>
  <targets>
    - backend/app/routers/submissions.py        (add two GET routes)
    - backend/app/schemas/submission.py         (add SubmissionOut, SubmissionItemOut)
    - backend/app/services/aggregates.py        (reuse mentor_circle_ids; do not copy it)
    - frontend/src/api.ts                       (mirror the two new response shapes)
    - frontend/src/surfaces/app/               (student "my past check-ins" view)
    - backend/tests/test_submissions_api.py     (extend; do not create a new file)
  </targets>
  <out-of-scope>
    - No new migration. `submissions` and `submission_items` already carry every
      column and RLS policy this needs — verify with `api-lookup`, do not add.
    - No change to `POST /api/submissions` or to submission_filing.py.
    - No staff/MEL/leadership read path. Those roles read aggregates, and
      widening them here would cross a consent boundary this goal has not
      cleared.
    - No edit to the existing RLS policies (`submissions_read_*`).
  </out-of-scope>
  <requirements>
    - **Pydantic is source of truth; api.ts mirrors it by hand in this same
      change.** `make contract` must pass. Field names are camelCase on the wire
      via `Field(alias=...)`, matching the existing schemas in this file.
    - **Mentor scoping is the route's job, not RLS.** Call
      `mentor_circle_ids(session, mentor.id)` and filter on it explicitly
      (architecture.md §2: "Mentor scoping is enforced in the router, not by
      RLS"). A route that omits the check is broken even though the policy
      exists — do not treat the policy as the check.
    - **Anonymous items must be unjoinable, not merely hidden.** The mentor read
      must exclude `submission_items.anonymous = true` rows outright — not null
      their text, not return them flagged. A count that changes when an
      anonymous row exists is a leak.
    - **A mentor from another circle gets zero rows, not a filtered count.** Do
      not return an empty-but-shaped payload that discloses the submission
      exists.
    - `consent_state` never widens on read. An item filed `internal_only` is not
      promoted because a mentor is the caller.
    - Student self-read is `participant_id == participant.id`. Do not accept a
      participant id from the request; resolve it from the token.
    - `require_role` on both routes, as the existing POST does. No route may be
      reachable unauthenticated — `make openapi` records `x-auth` and `make
      lint` fails while it is stale.
    - Must keep passing: `backend/tests/test_submissions_api.py`,
      `test_submission_filing.py`, `make lint`, `make test`.
    - No raw student text to any log sink. Log ids, never `item.text`.
  </requirements>
</plan>

# Implementation Phases

## Phase 1 — Read schemas
- [ ] `SubmissionItemOut` and `SubmissionOut` in `backend/app/schemas/submission.py`,
      aliased camelCase like their siblings
- [ ] `SubmissionOut` carries no field a mentor may not see; role filtering is
      done before serialisation, not by omitting fields at render time

## Phase 2 — Student self-read
- [ ] `GET /api/submissions` — the caller's own, newest first
- [ ] `GET /api/submissions/{id}` — 404 (not 403) when it is not theirs
- [ ] Tests: own submission readable; another student's is 404

## Phase 3 — Mentor circle-scoped read
- [ ] Same two routes resolve a mentor through `mentor_circle_ids`
- [ ] `anonymous = true` items excluded from the mentor payload entirely
- [ ] Tests: in-circle mentor sees it; out-of-circle mentor gets zero rows;
      an anonymous item is absent from the mentor view and present in the
      student's own view

## Phase 4 — Wire the contract
- [ ] Mirror both shapes in `frontend/src/api.ts`; `make contract` green
- [ ] `make openapi` regenerated
- [ ] Student "past check-ins" view reads the new route

## Phase 5 — Gates
- [ ] `make lint`
- [ ] `make test`
