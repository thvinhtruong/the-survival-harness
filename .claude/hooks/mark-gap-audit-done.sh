#!/usr/bin/env bash
# PostToolUse hook: when the post-plan-gap-audit skill is invoked, write the
# session marker so the Stop hook stops nudging.
#
# Pairs with check-gap-audit.sh.

set -euo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
skill=$(echo "$input" | jq -r '.tool_input.skill // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')

if [ "$tool_name" = "Skill" ] && [ "$skill" = "post-plan-gap-audit" ] && [ -n "$session_id" ]; then
  project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  mkdir -p "$project_dir/.claude/state"
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$project_dir/.claude/state/audit-$session_id"
fi
exit 0
