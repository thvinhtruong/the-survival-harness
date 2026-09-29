#!/usr/bin/env bash
# PreToolUse(Bash) gatekeeper: a HARD rule. Deterministically denies destructive
# shell/SQL/git ops and credential exfiltration before they run. The model
# cannot reason past this — it runs in the shell, outside the model.
#
# Pairs with: .claude/hooks/destructive-patterns.conf (tunable pattern list).
# Decision model (per project): gray-zone = hard deny, not "ask".
#
# Contract:
#   stdin  = PreToolUse JSON ({ tool_name, tool_input: { command } })
#   stdout = on deny, JSON with hookSpecificOutput.permissionDecision=deny
#   exit 0 always (deny is expressed in JSON, not via exit code)
#
# Fail-open: any missing dependency or parse failure lets the command through.
# This is a safety net, not a sandbox — see the .conf header for limitations.

set -uo pipefail

PATTERNS_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/hooks/destructive-patterns.conf"

deny() {
  # $1 = reason shown to the model/user
  local reason="$1"
  # Escape backslashes and double quotes for JSON embedding.
  reason=${reason//\\/\\\\}
  reason=${reason//\"/\\\"}
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED by destructive-ops guard: ${reason}. If this is genuinely intended, the user must run it manually or relax .claude/hooks/destructive-patterns.conf."
  }
}
EOF
  exit 0
}

input=$(cat)

# jq missing → fail-open (nudge infra absent, don't block work).
command -v jq >/dev/null 2>&1 || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# --- Context-sensitive checks the regex list can't express ----------------

# 1. DELETE / UPDATE without a WHERE clause = mass mutation.
if printf '%s' "$cmd" | grep -iqE '\bDELETE\s+FROM\b' \
   && ! printf '%s' "$cmd" | grep -iqE '\bWHERE\b'; then
  deny "DELETE FROM without a WHERE clause deletes every row"
fi
if printf '%s' "$cmd" | grep -iqE '\bUPDATE\s+\S+\s+SET\b' \
   && ! printf '%s' "$cmd" | grep -iqE '\bWHERE\b'; then
  deny "UPDATE without a WHERE clause rewrites every row"
fi

# 2. Force-push to a protected branch (allowed on feature branches).
if printf '%s' "$cmd" | grep -iqE '\bgit\s+push\b.*(--force\b|--force-with-lease\b|\s-f\b)' \
   && printf '%s' "$cmd" | grep -iqE '\b(main|master|develop|production)\b'; then
  deny "force-push targeting a protected branch (main/master/develop/production)"
fi

# 3. `git restore` discards working-tree content unless it is only unstaging.
#    Needs a negation the pattern file's grep -E cannot express.
if printf '%s' "$cmd" | grep -iqE '\bgit\s+restore\b' \
   && ! printf '%s' "$cmd" | grep -iqE '(^|\s)--staged(\s|$)'; then
  deny "git restore without --staged discards uncommitted changes in the working tree"
fi

# 4. `git checkout <path>` — the same working-tree loss as `git restore`, and the
#    `--` the pattern file matches on is optional. Told apart from a branch
#    checkout the only way that is reliable: an argument naming a file or
#    directory that exists right now is a path, not a ref. This gap cost a real
#    uncommitted edit, recovered only because a transcript happened to hold it.
if printf '%s' "$cmd" | grep -iqE '\bgit\s+checkout\b' \
   && ! printf '%s' "$cmd" | grep -qE '(^|\s)-[bB](\s|$)'; then
  # awk, not sed: BSD sed has no \b, so the extraction silently produced nothing
  # here and the check passed everything through on macOS.
  args=$(printf '%s' "$cmd" | tr ';|&' '\n' \
    | awk '{ for (i = 1; i <= NF; i++) if ($i == "checkout") { for (j = i+1; j <= NF; j++) printf "%s ", $j; exit } }')
  for a in $args; do
    case "$a" in -*|--) continue ;; esac
    if [ -e "${CLAUDE_PROJECT_DIR:-$(pwd)}/$a" ] || [ -e "$a" ]; then
      deny "git checkout of a path ($a) discards uncommitted changes in the working tree — use \`git stash\` or leave the file alone"
    fi
  done
fi

# --- Pattern-file checks --------------------------------------------------
[ -r "$PATTERNS_FILE" ] || exit 0

while IFS=$'\t' read -r tier regex reason; do
  # Skip comments / blanks / malformed lines.
  case "$tier" in ''|\#*) continue ;; esac
  [ -z "$regex" ] && continue
  if printf '%s' "$cmd" | grep -iqE "$regex"; then
    deny "${reason:-matched a destructive pattern}"
  fi
done < "$PATTERNS_FILE"

# No match → allow (falls through to normal permission flow).
exit 0
