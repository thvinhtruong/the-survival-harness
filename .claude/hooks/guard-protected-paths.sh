#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit): deny writes to files that are
# never hand-edited, before the edit happens rather than after.
#
# Two classes:
#
#   1. Generated files (GENERATED_FILES in .claude/harness.conf). "Edit the
#      source and regenerate" is stated in CLAUDE.md and enforced nowhere else —
#      a staleness gate only catches drift, never a hand-edit that happens to
#      look consistent.
#
#   2. The grading criteria (goal and debug logs, scripts/goal) while an
#      implementer is running. cook §6 gate 1 already voids such an attempt, but
#      only after the whole attempt is spent.
#
# Honest limitation: hook input does not identify the spawning agent, so class 2
# keys off a marker the cook skill writes before it spawns and clears after. A
# missing marker fails open — it is a cheap save on a known failure mode, not a
# sandbox.
set -uo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

deny() {
  local reason="$1"
  reason=${reason//\\/\\\\}; reason=${reason//\"/\\\"}
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED by protected-paths guard: ${reason}"
  }
}
EOF
  exit 0
}

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
[ -z "$path" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
GENERATED_FILES=""
# shellcheck source=/dev/null
[ -r "$project_dir/.claude/harness.conf" ] && . "$project_dir/.claude/harness.conf"

for g in $GENERATED_FILES; do
  case "$path" in
  *"$g") deny "$g is generated. Edit its source and regenerate — the Doc map in CLAUDE.md names the command." ;;
  esac
done

[ -f "$project_dir/.claude/state/implementer-active" ] || exit 0

case "$path" in
*docs/backlogs/goals/*|*docs/backlogs/debug/*.jsonl|*scripts/goal)
  deny "the state log is the grading criteria, not a working file (implementer.md). If the state cannot be reached within its forbids, stop and report \`infeasible\` with a reason — do not edit the goal." ;;
esac
exit 0
