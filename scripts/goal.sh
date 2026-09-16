#!/bin/sh
# A goal is a transfer between states. This is the append-only log of those
# states, one per line, newest last — so `tail -1` is where the work stands and
# reading it costs nothing. It sits beside the plan.md it belongs to; `active/`
# is the status, so no state carries one.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLANS=$ROOT/docs/backlogs/plans

die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
	cat <<'USAGE'
goal.sh — the state log beside a plan

  new <slug> <title>   plan.md + goal.xml under plans/active/<date-slug>/
  add <text>           append the state now reached
  edit <text>          reword the last state (append-only: correct by adding)
  get                  the current state, one line
  show                 the whole transfer, oldest first
  path                 where the log lives

Set GOAL=<path/to/goal.xml> to address a log other than the one in active/.
USAGE
}

# active/ holds the goal in flight; one at a time, so one match is expected.
resolve() {
	if [ -n "${GOAL:-}" ]; then
		[ -f "$GOAL" ] || die "GOAL=$GOAL does not exist"
		printf '%s\n' "$GOAL"
		return
	fi
	set -- "$PLANS"/active/*/goal.xml
	[ -f "$1" ] || die "no goal.xml under docs/backlogs/plans/active — start one with \`goal.sh new <slug> <title>\`"
	if [ "$#" -gt 1 ]; then
		printf 'more than one goal in active/:\n' >&2
		printf '  %s\n' "$@" >&2
		die 'one goal at a time — move the rest to done/, or set GOAL=<path>'
	fi
	printf '%s\n' "$1"
}

esc() { printf '%s' "$1" | tr '\n\t' '  ' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
unesc() { sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g'; }

last_line() { tail -n 1 "$1" 2>/dev/null || :; }
last_num() { last_line "$1" | sed -n 's/.*id="S\([0-9]\{1,\}\)".*/\1/p'; }

# id at text -> aligned columns, entities back to characters
render() {
	sed -n 's|^<state id="\([^"]*\)" at="\([^"]*\)">\(.*\)</state>$|\1	\2	\3|p' | unesc |
		awk -F'\t' '{ printf "  %-4s %s  %s\n", $1, $2, $3 }'
}

write_state() { # file id text
	printf '<state id="S%s" at="%s">%s</state>\n' "$2" "$(date -u +%Y-%m-%dT%H:%MZ)" "$(esc "$3")" >>"$1"
}

cmd_new() {
	[ "$#" -eq 2 ] || die 'usage: goal.sh new <slug> <title>'
	d=$PLANS/active/$(date +%y%m%d-%H%M)-$1
	[ -e "$d" ] && die "$d already exists"
	mkdir -p "$d"
	sed "s|{{short descriptive title}}|$2|" "$PLANS/_TEMPLATE.md" >"$d/plan.md"
	: >"$d/goal.xml"
	printf 'created %s/  (plan.md + empty goal.xml)\n' "${d#"$ROOT"/}"
	printf 'first state: goal.sh add "<where the repo stands now>"\n'
}

cmd_add() {
	[ "$#" -eq 1 ] && [ -n "$1" ] || die 'usage: goal.sh add "<state reached>"'
	f=$(resolve)
	n=$(last_num "$f")
	write_state "$f" "$(( ${n:-0} + 1 ))" "$1"
	last_line "$f" | render
}

cmd_edit() {
	[ "$#" -eq 1 ] && [ -n "$1" ] || die 'usage: goal.sh edit "<reworded state>"'
	f=$(resolve)
	n=$(last_num "$f") || :
	[ -n "$n" ] || die 'log is empty — nothing to edit'
	t=$(mktemp) && sed '$d' "$f" >"$t" && mv "$t" "$f"
	write_state "$f" "$n" "$1"
	last_line "$f" | render
}

cmd_get() {
	f=$(resolve)
	l=$(last_line "$f")
	[ -n "$l" ] || die "no state logged yet in ${f#"$ROOT"/}"
	printf '%s\n' "$l" | render
}

cmd_show() {
	f=$(resolve)
	d=${f%/goal.xml}
	printf '%s\n' "${d#"$ROOT"/}/plan.md"
	if [ -s "$f" ]; then
		render <"$f"
	else
		printf '  (no state logged yet)\n'
	fi
}

[ "$#" -gt 0 ] || { usage; exit 1; }
cmd=$1
shift
case $cmd in
new) cmd_new "$@" ;;
add) cmd_add "$@" ;;
edit) cmd_edit "$@" ;;
get | last) cmd_get ;;
show) cmd_show ;;
path) resolve ;;
-h | --help | help) usage ;;
*) die "unknown command: $cmd" ;;
esac
