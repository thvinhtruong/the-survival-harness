#!/usr/bin/env bash
# SessionStart hook. Three jobs, all of them "put the state in front of the agent":
#
#   1. Record the session baseline — the commit the session starts from. The Stop
#      hooks diff against it, so committing mid-session no longer hides the work.
#   2. Print the goal. An instruction to "call goal show" would degrade under
#      context pressure; a hook does not.
#   3. Print how often the escape hatches were used recently. The skip marker
#      costs one command and the work it skips costs ten minutes, so over enough
#      sessions the marker wins unless someone can see it happening.
set -euo pipefail
input=$(cat)

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir" || exit 0
# shellcheck source=/dev/null
. "$project_dir/.claude/hooks/lib.sh"

prune_state

# The baseline is written once. A resume keeps the original, so a long session
# that compacts does not quietly shrink its own diff.
sid=""
if command -v jq >/dev/null 2>&1; then
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""')
fi
[ -n "$sid" ] || sid="${CLAUDE_SESSION_ID:-}"
if [ -n "$sid" ] && [ -z "$(session_baseline "$sid")" ]; then
  log_event "session	${sid:0:8}	start	$(git rev-parse HEAD 2>/dev/null || echo no-head)"
fi

if state=$(scripts/goal show 2>/dev/null) && [ -n "$state" ]; then
  printf '%s\n' "$state" | sed 's/^/  /' | {
    echo "Open goal (scripts/goal) — there is no plan; the states and their forbids are the whole brief:"
    cat
    echo "  The newest unreached state is the target (✓ = reached, with evidence). ✗ lines are approaches not to retry."
  }
else
  # Silence here made the mechanism look absent rather than idle.
  echo "No open goal in docs/backlogs/goals/ — \`/cook\` starts one."
fi

# A bug fix in flight is a debug log; silent when there is none — /debug is
# not something to advertise every session.
if state=$(scripts/goal --debug now 2>/dev/null) && [ -n "$state" ]; then
  echo "Open debug log (scripts/goal --debug) — Reproduced → Fixed → Recorded; → is the target:"
  printf '%s\n' "$state" | sed 's/^/  /'
fi

# Erosion is only visible in aggregate; one skip is fine, five in a row is a signal.
# Read straight out of the one log — the separate skips.log said the same thing.
if [ -f "$HARNESS_LOG" ]; then
  awk -F'\t' '$2=="record" && $4=="SKIPPED" { n++; a[n%3]=sprintf("  %s  %-10s %s", $1, substr($3,6), $6) }
    END {
      if (n) {
        printf "Stop-hook skips recorded in this log: %d. Most recent:\n", n
        for (i = n-2; i <= n; i++) if (i > 0) print a[i%3]
      }
    }' "$HARNESS_LOG"
fi
exit 0
