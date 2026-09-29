#!/usr/bin/env bash
# Stop hook: docs are updated only when a change BREAKS a contract. This fires
# when the session touched a contract-bearing surface (DOC_SYNC_CONTRACT_PATHS
# in .claude/harness.conf) and no doc moved with it.
#
# Scope is the SESSION (baseline..HEAD plus the working tree), so a mid-session
# commit no longer empties the count.
#
# docs/backlogs/** does NOT count as a doc — goal logs and notes are working
# files, not the contract record.
#
# Escape hatch: scripts/skip.sh doc-sync "<reason>"
set -euo pipefail

input=$(cat)

# jq missing → fail-open. This hook is a nudge, not a gate.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Avoid re-blocking on the same turn.
[ "$stop_hook_active" = "true" ] && exit 0
[ -z "$session_id" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# shellcheck source=/dev/null
. "$project_dir/.claude/hooks/lib.sh"

if record_is_current "skip-doc-sync"; then
  exit 0
fi

files=$(session_files "$session_id")

# Contract-bearing surfaces: a change here can break a documented contract.
# Anything else is behaviour-preserving as far as the docs are concerned.
# The list is DOC_SYNC_CONTRACT_PATHS in .claude/harness.conf.
breaking=$(printf '%s\n' "$files" | grep -cE "$DOC_SYNC_CONTRACT_PATHS" || true)

# Nothing contract-bearing changed — no doc is owed.
if [ "${breaking:-0}" -lt 1 ]; then
  exit 0
fi

# Real docs only: the reference prose, CLAUDE.md, the generated contracts.
# Goal logs and backlog notes are working files, not the contract record.
doc_changed=$(printf '%s\n' "$files" \
  | grep -vE '^docs/backlogs/' \
  | grep -cE "$DOC_SYNC_DOC_PATHS" || true)

# Docs were touched — assume the user handled it.
if [ "${doc_changed:-0}" -gt 0 ]; then
  exit 0
fi

log_event "doc-sync	block	$breaking surfaces"
cat <<EOF
{
  "decision": "block",
  "reason": "Stop blocked by doc-sync hook: $breaking contract-bearing file(s) changed this session (DOC_SYNC_CONTRACT_PATHS in .claude/harness.conf), 0 doc files updated. The goal log does not count — it is a working file, not the contract record.\n\nDocs are owed only when something BREAKS — a response shape, a schema or access-control decision, an invariant, a route or layout owner, a design token or component spec. Do ONE of:\n\n1. **Update the docs** named in the \"Update when it breaks\" column of the **Doc map** in root \`CLAUDE.md\`, for the area you changed. Rule and escape hatch: the \`cook\` skill §10.\n\n2. **Skip explicitly** if nothing broke (behaviour-preserving refactor, test-only, revert):\n   \`scripts/skip.sh doc-sync '<one-line reason>'\`\n\nDo not stop without doing one of these. The skip is keyed to the current tree and is logged."
}
EOF
exit 0
