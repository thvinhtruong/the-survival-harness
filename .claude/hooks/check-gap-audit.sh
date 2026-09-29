#!/usr/bin/env bash
# Stop hook: substantial implementation without the gap-audit.
#
# Scope is the SESSION (baseline..HEAD plus the working tree), not the working
# tree alone — a mid-session commit is routine, and a working-tree-only
# count went quiet on exactly the sessions that finished something.
#
# Escape hatch: scripts/skip.sh gap-audit "<reason>"
set -euo pipefail

input=$(cat)

# jq missing → fail-open. This hook is a nudge, not a gate.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Avoid re-blocking on the same turn (Stop fires again after the model continues).
[ "$stop_hook_active" = "true" ] && exit 0
[ -z "$session_id" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# shellcheck source=/dev/null
. "$project_dir/.claude/hooks/lib.sh"

# Audited, or explicitly skipped, against THIS tree. Both lapse on the next edit.
if record_is_current "skip-gap-audit"; then
  exit 0
fi

# Extensions and threshold: GAP_AUDIT_* in .claude/harness.conf.
changed=$(session_files "$session_id" \
  | grep -cE "${GAP_AUDIT_EXTENSIONS:-\.(py|ts|tsx)$}" || true)

if [ "${changed:-0}" -lt "${GAP_AUDIT_THRESHOLD:-5}" ]; then
  exit 0
fi

log_event "gap-audit	block	$changed files"
cat <<EOF
{
  "decision": "block",
  "reason": "Stop blocked by gap-audit hook: $changed code files changed this session (commits since the session baseline + working tree) and the gap-audit has NOT been run.\n\nBefore finishing:\n\n1. **If this was feature work** — invoke the audit skill now:\n   Use the Skill tool with skill=\"gap-audit\".\n   It will check for unreachable code, wiring gaps, and silent divergences across package boundaries — the bugs that compile and pass unit tests but never actually run.\n\n2. **If this was NOT feature work** (refactor, doc-only with code touchups, simple bug fix) — skip explicitly:\n   \`scripts/skip.sh gap-audit '<one-line reason>'\`\n\nThe skill records itself on completion, so option 1 needs no manual step. Either way the record is keyed to the current tree: it lapses on your next edit."
}
EOF
exit 0
