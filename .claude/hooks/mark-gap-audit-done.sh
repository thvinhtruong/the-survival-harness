#!/usr/bin/env bash
# PostToolUse hook: the gap-audit skill ran, so record it against the
# tree it ran on. Pairs with check-gap-audit.sh.
#
# Fires on EVERY Skill call, so it must be cheap and quiet: it writes only when
# the skill was the audit AND this tree has no current record yet. Re-invoking the
# audit on an unchanged tree used to append a fresh record every time, which said
# nothing new and pushed the lines that matter out of the log.
set -euo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
skill=$(echo "$input" | jq -r '.tool_input.skill // ""')

[ "$tool_name" = "Skill" ] && [ "$skill" = "gap-audit" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# shellcheck source=/dev/null
. "$project_dir/.claude/hooks/lib.sh"

record_is_current "skip-gap-audit" && exit 0

"$project_dir/scripts/skip.sh" --ran gap-audit "gap-audit skill completed" >/dev/null 2>&1 || :
exit 0
