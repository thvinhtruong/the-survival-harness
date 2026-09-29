#!/usr/bin/env bash
# Stop hook: append this turn's token usage to harness.log.
#
# No model is involved and none is needed. Claude Code already writes every API
# call's usage to the session transcript; this reads it back with jq. Two things
# make the arithmetic right:
#
#   - Dedupe by requestId. One API call is split across several transcript lines
#     (a text block, then each tool_use block) that repeat the SAME usage object,
#     so summing lines double-counts.
#   - isSidechain separates subagent work from the main thread, which is what
#     makes "which part of the run cost what" answerable at all.
#
# It logs the DELTA since the last line for this session, so one line per turn
# adds up to the run, and the log itself is the watermark — no extra state file.
#
# Fields: calls, out(put), cw (cache write), cr (cache read), in (uncached input).
# Do not sum them into one number: cache reads dominate volume and are billed at a
# fraction of input, cache writes at a premium.
set -euo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

session_id=$(echo "$input" | jq -r '.session_id // ""')
transcript=$(echo "$input" | jq -r '.transcript_path // ""')
[ -n "$session_id" ] || exit 0
[ -f "$transcript" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# shellcheck source=/dev/null
. "$project_dir/.claude/hooks/lib.sh"

sid=${session_id:0:8}

# Cumulative totals for the whole transcript, one line per agent plane.
totals=$(jq -rs '
  map(select(.message.usage != null and .requestId != null))
  | unique_by(.requestId)
  | group_by(.isSidechain == true)
  | map({
      agent: (if .[0].isSidechain == true then "subagent" else "main" end),
      calls: length,
      out: (map(.message.usage.output_tokens // 0) | add),
      cw:  (map(.message.usage.cache_creation_input_tokens // 0) | add),
      cr:  (map(.message.usage.cache_read_input_tokens // 0) | add),
      inp: (map(.message.usage.input_tokens // 0) | add)
    })
  | .[] | [.agent, .calls, .out, .cw, .cr, .inp] | @tsv
' "$transcript" 2>/dev/null) || exit 0

[ -n "$totals" ] || exit 0

while IFS=$'\t' read -r agent calls out cw cr inp; do
  [ -n "$agent" ] || continue
  # Everything already logged for this session and plane; the delta is the turn.
  prior=$(awk -F'\t' -v s="$sid" -v a="$agent" '
    $2=="tokens" && $3==s && $4==a {
      for (i=5; i<=NF; i++) {
        split($i, kv, "=")
        sum[kv[1]] += kv[2]
      }
    }
    END { printf "%d %d %d %d %d", sum["calls"], sum["out"], sum["cw"], sum["cr"], sum["in"] }
  ' "$HARNESS_LOG" 2>/dev/null) || prior="0 0 0 0 0"
  set -- $prior
  d_calls=$((calls - $1)) d_out=$((out - $2)) d_cw=$((cw - $3)) d_cr=$((cr - $4)) d_in=$((inp - $5))
  [ "$d_calls" -gt 0 ] || continue
  log_event "tokens	$sid	$agent	calls=$d_calls	out=$d_out	cw=$d_cw	cr=$d_cr	in=$d_in"
done <<<"$totals"

exit 0
