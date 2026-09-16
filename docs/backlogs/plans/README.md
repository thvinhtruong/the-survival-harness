# Plans — the live goal, and the record of past ones

`active/<id>/` is the goal in flight: `goal.xml` (the append-only state log,
navigated with `scripts/goal.sh`) beside `plan.md` (the contract the implementer
codes against). `active/` is the status — one folder at a time, and a
SessionStart hook surfaces its log on its own.

`done/` and `archived/` are history and **not** a mandated read; nothing there
loads into context automatically. Open one only when you are working on that
exact area and need its reasoning. Git is the authoritative archive.

`_TEMPLATE.md` is what `goal.sh new` copies. `_EXAMPLE/` is a worked pair —
a `goal.xml` beside the `plan.md` that goes with it — showing the division of
labour: the log says what the user wants, the plan carries everything a cold
implementer cannot infer. Both `_` names sit outside `active/`, so `goal.sh`
never mistakes them for a live goal.

<!-- Projects that archive a plan for a reason worth remembering add a table
     here: | Plan | Why |. Keep it to decisions a future reader would otherwise
     re-litigate. -->
