#!/usr/bin/env bash
# SessionStart hook: put the current state in front of the agent. This is what
# keeps the goal as reliable as the mandated TASK.md read it replaced — an
# instruction to "call goal.sh show" would degrade under context pressure; a
# hook does not.
set -euo pipefail
cat >/dev/null   # drain hook stdin

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir" || exit 0

state=$(scripts/goal.sh show 2>/dev/null) || exit 0
[ -z "$state" ] && exit 0

printf '%s\n' "$state" | sed 's/^/  /' | {
  echo "Current goal — the state log beside the active plan (scripts/goal.sh):"
  cat
  echo "  The last state is where the repo stands. \`goal.sh add\` once the next one is reached."
}
exit 0
