#!/usr/bin/env bash
# Shared helpers for the hooks. Sourced, never executed.
#
# Three ideas hold the rest together:
#
#   - A session's work is (baseline..HEAD) PLUS the working tree. Measuring only
#     the working tree meant a mid-session commit hid the whole session from the
#     Stop hooks — they fired on abandoned work and stayed quiet on finished work.
#
#   - A gate result or a skip is evidence only while the tree it was recorded
#     against is unchanged. Keying on a fingerprint rather than a session id makes
#     "green" self-invalidating, and removes the $SESSION_ID the model cannot
#     expand in its own shell.
#
#   - ONE file. harness.log is the whole of the state: events, records and the
#     session baselines all live in it, append-only, tab-separated. The fleet of
#     *.last marker files and the second log it used to keep were four writes to
#     say one thing, and each was a place for the truth to drift.
#
# Line shapes (field 1 is always the UTC minute):
#   TS  session   <sid8>  start   <full-sha>        session baseline
#   TS  record    <key>   <STATUS> <fingerprint> <reason>
#   TS  tokens    <sid8>  <main|subagent> <k=v ...>
#   TS  <check>   block   <detail>                  a Stop hook fired
#
# Records are read last-wins, so a correction is another append.

HARNESS_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HARNESS_STATE="$HARNESS_ROOT/.claude/state"
HARNESS_LOG="$HARNESS_STATE/harness.log"

# The per-repo values (gates, contract paths, gap-audit threshold).
# shellcheck source=/dev/null
[ -r "$HARNESS_ROOT/.claude/harness.conf" ] && . "$HARNESS_ROOT/.claude/harness.conf"

state_dir() { mkdir -p "$HARNESS_STATE" 2>/dev/null || :; printf '%s' "$HARNESS_STATE"; }

# One tab-separated line per event. Only things worth reading later: a block, a
# record, a baseline, a token roll-up. A hook that passes says nothing — a log
# that prints "fine" once per turn is noise that hides the two lines that matter.
log_event() {
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$*" >>"$(state_dir)/harness.log" 2>/dev/null || :
}

# The tree the gates would run against. Single definition lives in
# scripts/gate-record.sh so the Makefile and the hooks cannot drift apart.
tree_fingerprint() {
  "$HARNESS_ROOT/scripts/gate-record.sh" --print 2>/dev/null || printf 'unknown'
}

# --- records -----------------------------------------------------------------
# A recorded fact (gate pass, skip, audit run) counts only while the tree it was
# recorded against is the tree we are looking at now.

record_line() { # $1 key -> the most recent record line for that key, or nothing
  [ -f "$HARNESS_LOG" ] || return 1
  awk -F'\t' -v k="$1" '$2=="record" && $3==k { line=$0 } END { if (line) print line }' \
    "$HARNESS_LOG"
}

record_is_current() { # $1 key
  local line fp
  line=$(record_line "$1") || return 1
  [ -n "$line" ] || return 1
  fp=$(printf '%s' "$line" | cut -f5)
  [ -n "$fp" ] && [ "$fp" = "$(tree_fingerprint)" ]
}

record_status() { record_line "$1" | cut -f4; }
record_when()   { record_line "$1" | cut -f1; }

# --- session -----------------------------------------------------------------
# Where the session started. Written once by the SessionStart hook; a resume
# keeps the first one, so the baseline does not creep forward across a compaction.
session_baseline() {
  [ -f "$HARNESS_LOG" ] || return 0
  awk -F'\t' -v s="${1:0:8}" '$2=="session" && $3==s && $4=="start" { print $5; exit }' \
    "$HARNESS_LOG"
}

# Every file this session touched: committed since the baseline, plus whatever
# is still uncommitted. Rename lines from porcelain are reduced to their target;
# --untracked-files=all, or a new directory shows as `dir/` and its files are
# invisible to every pattern that matches on an extension.
session_files() {
  local sid="$1" base
  base=$(session_baseline "$sid")
  cd "$HARNESS_ROOT" 2>/dev/null || return 0
  {
    [ -n "$base" ] && git diff --name-only "$base" HEAD 2>/dev/null
    git status --porcelain --untracked-files=all 2>/dev/null | cut -c4- | sed 's/.* -> //'
  } | sed '/^$/d' | sort -u
}

# Hygiene: the log is the only durable thing here. implementer-active is a live
# flag the cook skill toggles; anything else left in the directory is from an
# older layout and is not read any more.
prune_state() {
  local dir; dir=$(state_dir)
  find "$dir" -maxdepth 1 -type f ! -name 'harness.log' ! -name 'implementer-active' \
    -delete 2>/dev/null || :
  # Trim to the last 600 lines, but never past the newest session baseline: the
  # token roll-up reads its own previous lines to compute a delta, so cutting
  # them mid-session (SessionStart also fires on a compaction) would make the
  # next turn's numbers count the whole session again.
  local total keep start
  total=$(wc -l 2>/dev/null <"$HARNESS_LOG" || echo 0)
  if [ -f "$HARNESS_LOG" ] && [ "$total" -gt 800 ]; then
    keep=600
    start=$(awk -F'\t' '$2=="session" && $4=="start" { n=NR } END { print n+0 }' "$HARNESS_LOG")
    [ "$start" -gt 0 ] && [ $((total - start + 1)) -gt "$keep" ] && keep=$((total - start + 1))
    tail -n "$keep" "$HARNESS_LOG" >"$HARNESS_LOG.tmp" 2>/dev/null \
      && mv "$HARNESS_LOG.tmp" "$HARNESS_LOG" 2>/dev/null || :
  fi
}
