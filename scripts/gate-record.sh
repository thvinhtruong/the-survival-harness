#!/bin/sh
# Records that a gate passed, against the exact tree it passed on.
#
# Called as the last line of a Makefile gate recipe: make stops at the first
# failing line, so reaching this line IS the pass. Nothing has to observe an exit
# code — which matters, because the Bash tool result the hooks can see does not
# carry one.
#
#   gate-record.sh lint     record a pass for the `lint` gate
#   gate-record.sh --print  print the current tree fingerprint (single definition;
#                           .claude/hooks/lib.sh calls this so the two cannot drift)
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE=$ROOT/.claude/state

# HEAD + what is staged/unstaged + the content of every tracked change + the
# content of every untracked file. Untracked content matters: a new router or a
# new component is untracked for its whole first session, and hashing only its
# name let a green gate survive every later edit to it. Gitignored files are not
# listed by --exclude-standard, so this stays bounded. .claude/state/ is excluded
# explicitly as well as by .gitignore: recording a pass must never be the thing
# that invalidates it, even if the ignore rule breaks again.
fingerprint() {
	{
		git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo no-head
		git -C "$ROOT" status --porcelain 2>/dev/null | grep -v '\.claude/state/' || :
		git -C "$ROOT" diff HEAD 2>/dev/null || :
		git -C "$ROOT" ls-files --others --exclude-standard -z 2>/dev/null \
			| (cd "$ROOT" && xargs -0 shasum 2>/dev/null) | grep -v '\.claude/state/' || :
	} | shasum | cut -d' ' -f1
}

[ "$#" -ge 1 ] || { echo 'usage: gate-record.sh <gate-name> | --print' >&2; exit 2; }

if [ "$1" = "--print" ]; then
	fingerprint
	exit 0
fi

# One append to the one log. The record IS the log line — see the line shapes in
# .claude/hooks/lib.sh.
mkdir -p "$STATE"
printf '%s\trecord\tgate-%s\tPASS\t%s\tmake %s\n' \
	"$(date -u +%Y-%m-%dT%H:%MZ)" "$1" "$(fingerprint)" "$1" >>"$STATE/harness.log"
