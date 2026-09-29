#!/usr/bin/env bash
# UserPromptSubmit hook: one line, the current state.
#
# The SessionStart injection is exactly what decays across a long, compacted
# session — the same failure mode the hook was built to prevent, reintroduced by
# duration. This costs ~20 tokens a prompt to keep it fresh.
#
# Silent when nothing is in flight: SessionStart says that once, and repeating it
# on every prompt would be nagging, not context.
set -euo pipefail
cat >/dev/null

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir" || exit 0

# A goal and a debug log may both be open; each gets its one line.
if state=$(scripts/goal now 2>/dev/null) && [ -n "$state" ]; then
  printf 'Open state (scripts/goal now):%s\n' "$(printf '%s' "$state" | sed 's/^ */ /' | tr '\n' ' ')"
fi
if state=$(scripts/goal --debug now 2>/dev/null) && [ -n "$state" ]; then
  printf 'Open debug (scripts/goal --debug now):%s\n' "$(printf '%s' "$state" | sed 's/^ */ /' | tr '\n' ' ')"
fi
exit 0
