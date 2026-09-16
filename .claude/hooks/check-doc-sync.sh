#!/usr/bin/env bash
# Stop hook: docs are updated only when a change BREAKS a contract. This fires
# when the session touched a contract-bearing surface and no doc moved with it.
#
# What counts as contract-bearing is DOC_SYNC_CONTRACT_PATHS in
# .claude/harness.conf — the only thing to edit when adopting this in a repo.
#
# Escape hatch: write .claude/state/doc-sync-$SESSION_ID with a skip reason.

set -euo pipefail

input=$(cat)

# jq missing → fail-open. This hook is a nudge, not a gate.
command -v jq >/dev/null 2>&1 || exit 0

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Avoid re-blocking on the same turn.
[ "$stop_hook_active" = "true" ] && exit 0
[ -z "$session_id" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
conf="$project_dir/.claude/harness.conf"

# Unconfigured → fail-open. An unadopted harness must not block anyone's Stop.
[ -r "$conf" ] || exit 0
# shellcheck source=/dev/null
. "$conf"
[ -n "${DOC_SYNC_CONTRACT_PATHS:-}" ] || exit 0
[ "$DOC_SYNC_CONTRACT_PATHS" = "(NOTHING_CONFIGURED_YET)" ] && exit 0

marker="$project_dir/.claude/state/doc-sync-$session_id"

# Already synced (or explicitly skipped) this session.
[ -f "$marker" ] && exit 0

breaking=$(cd "$project_dir" && { git status --porcelain -uall 2>/dev/null \
  | grep -E "$DOC_SYNC_CONTRACT_PATHS" || true; } \
  | wc -l | tr -d ' ')

# Nothing contract-bearing changed — no doc is owed.
[ "${breaking:-0}" -lt 1 ] && exit 0

doc_changed=$(cd "$project_dir" && { git status --porcelain -uall 2>/dev/null \
  | grep -E "${DOC_SYNC_DOC_PATHS:-docs/.*\.md}" || true; } \
  | wc -l | tr -d ' ')

# Docs were touched — assume it was handled.
[ "${doc_changed:-0}" -gt 0 ] && exit 0

cat <<EOF
{
  "decision": "block",
  "reason": "Stop blocked by doc-sync hook: $breaking contract-bearing file(s) changed, 0 doc files updated.\n\nDocs are owed only when something BREAKS — a response shape, a schema or RLS decision, an invariant, a route or layout owner, a design token or component spec. Do ONE of:\n\n1. **Update the docs** named in the \"Update when it breaks\" column of the **Doc map** in root \`CLAUDE.md\`, for the area you changed. Rule and escape hatch: the \`cook\` skill §10.\n\n2. **Skip explicitly** if nothing broke (behaviour-preserving refactor, test-only, revert):\n   \`mkdir -p .claude/state && echo 'skipped: <one-line reason>' > .claude/state/doc-sync-$session_id\`\n\nDo not stop without doing one of these."
}
EOF
exit 0
