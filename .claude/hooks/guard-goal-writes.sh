#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit|Bash): the live goal log is
# append-only, and this is what makes that a property of the system rather than
# a promise in prose — always, not only while an implementer runs.
#
# Every write goes through `scripts/goal`, which only ever appends. Direct
# writes — Edit/Write on the file, a shell redirect, sed -i, tee, rm, mv — are
# denied. Reads are deliberately NOT gated: the log is a handful of lines, and
# tampering is also caught by cook §6 gate 1 (`git diff --name-only`).
#
# Scope is the logs themselves — goals/*.jsonl and debug/*.jsonl. README.md,
# _EXAMPLE.jsonl and the older .md lessons are documentation.
#
# Fail-open: missing jq or an unparseable payload lets the call through. This is
# a discipline rail, not a sandbox.
set -uo pipefail

GOALS_RE='docs/backlogs/(goals|debug)/[^_[:space:]][^[:space:]]*\.jsonl'

deny() {
  local reason="$1"
  reason=${reason//\\/\\\\}; reason=${reason//\"/\\\"}
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED by goal-log guard: ${reason}. The goal log is append-only — use \`scripts/goal add|amend|failed|reached|close\`. Correct a wrong state by appending (\`goal amend\`), never by rewriting a line."
  }
}
EOF
  exit 0
}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')

case "$tool_name" in
Write | Edit | MultiEdit | NotebookEdit)
  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
  printf '%s' "$path" | grep -qE "$GOALS_RE" && deny "$tool_name on the goal log ($path)"
  exit 0
  ;;
Bash) ;;
*) exit 0 ;;
esac

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
printf '%s' "$cmd" | grep -qE "$GOALS_RE" || exit 0

# A redirect whose TARGET is the log. Reading it and redirecting the result
# elsewhere is fine, so the path must follow the operator.
if printf '%s' "$cmd" | grep -qE '>>?[[:space:]]*[^|;&]*'"$GOALS_RE"; then
  deny "shell redirect writing to the goal log"
fi

if printf '%s' "$cmd" | grep -qE '\bsed[[:space:]]+[^|;&]*-i\b'; then
  deny "sed -i rewrites lines in place; the log is append-only"
fi
for verb in tee rm mv cp dd install ln truncate; do
  if printf '%s' "$cmd" | grep -qE "\\b${verb}\\b[^|;&]*${GOALS_RE}"; then
    deny "\`${verb}\` targeting the goal log"
  fi
done

exit 0
