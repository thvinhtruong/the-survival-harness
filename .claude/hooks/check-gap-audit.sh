#!/usr/bin/env bash
# Stop hook: if the session made substantial code changes without running the
# post-plan-gap-audit skill, block the stop and inject a reminder. Writing the
# session marker file lets the user skip (e.g. for doc-only changes).
#
# Extensions and threshold come from .claude/harness.conf.
# The skill writes the marker automatically via the PostToolUse hook.

set -euo pipefail

input=$(cat)

# jq is the cleanest way to parse hook input. Fail-open if jq is missing —
# this hook is a nudge, not a gate, and must never break the session.
command -v jq >/dev/null 2>&1 || exit 0

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Avoid re-blocking on the same turn (Stop fires again after the model continues).
[ "$stop_hook_active" = "true" ] && exit 0
[ -z "$session_id" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
conf="$project_dir/.claude/harness.conf"
[ -r "$conf" ] && . "$conf"

exts="${GAP_AUDIT_EXTENSIONS:-\.(go|ts|tsx|js|jsx|py|rs|java|kt|swift)$}"
threshold="${GAP_AUDIT_THRESHOLD:-5}"

marker="$project_dir/.claude/state/audit-$session_id"

# Already audited (or explicitly skipped) this session.
[ -f "$marker" ] && exit 0

# Count code-file changes. Threshold tuned to "real implementation" — small
# tweaks under this don't warrant the audit ceremony.
# Note: grep exits 1 on no-match, which under pipefail would make a trailing
# `|| echo 0` fire *after* wc/tr already printed "0" — doubling the output.
# Neutralize grep's exit code with `|| true` before it reaches the pipe.
changed=$(cd "$project_dir" && { git status --porcelain -uall 2>/dev/null \
  | grep -E "$exts" || true; } \
  | wc -l | tr -d ' ')

[ "${changed:-0}" -lt "$threshold" ] && exit 0

cat <<EOF
{
  "decision": "block",
  "reason": "Stop blocked by gap-audit hook: $changed code files modified this session and the post-plan-gap-audit has NOT been run.\n\nBefore finishing:\n\n1. **If this was a plan implementation** — invoke the audit skill now:\n   Use the Skill tool with skill=\"post-plan-gap-audit\".\n   It will check for unreachable code, wiring gaps, and silent divergences across package boundaries — the bugs that compile and pass unit tests but never actually run.\n\n2. **If this was NOT plan-style work** (refactor, doc-only with code touchups, simple bug fix) — skip explicitly by writing the marker:\n   \`mkdir -p .claude/state && echo 'skipped: <one-line reason>' > .claude/state/audit-$session_id\`\n   Then stop normally.\n\nThe skill auto-writes the marker on completion, so option 1 needs no manual marker step."
}
EOF
exit 0
