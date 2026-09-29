#!/bin/sh
# The escape hatch for the Stop hooks, and the record of having used one.
#
#   skip.sh doc-sync "nothing broke: behaviour-preserving refactor"
#   skip.sh --ran gap-audit "gap-audit skill completed"
#
# Checks: gap-audit | doc-sync
#
# Keyed to the tree, not the session: the skip dies the moment you edit again, and
# the command needs no $SESSION_ID — which the model cannot expand in its own
# shell, and which is how a real audit result once landed in a file named
# `.claude/state/audit-` that no hook would ever read.
#
# One append to .claude/state/harness.log, which is the record and the log at
# once. It used to be three writes — a marker file, a skips log and an event line
# — saying the same thing in three places.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE=$ROOT/.claude/state

status=SKIPPED
if [ "${1:-}" = "--ran" ]; then status=RAN; shift; fi

[ "$#" -eq 2 ] && [ -n "$2" ] || {
	echo 'usage: skip.sh [--ran] <gap-audit|doc-sync> "<one-line reason>"' >&2
	exit 2
}

case $1 in
gap-audit | doc-sync) ;;
*) echo "unknown check: $1 (gap-audit | doc-sync)" >&2; exit 2 ;;
esac

reason=$(printf '%s' "$2" | tr '\n\t' '  ')

mkdir -p "$STATE"
printf '%s\trecord\tskip-%s\t%s\t%s\t%s\n' \
	"$(date -u +%Y-%m-%dT%H:%MZ)" "$1" "$status" "$("$ROOT/scripts/gate-record.sh" --print)" "$reason" \
	>>"$STATE/harness.log"
printf '%s %s — recorded against the current tree; it lapses on your next edit.\n' "$status" "$1"
