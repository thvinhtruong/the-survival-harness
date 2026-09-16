#!/usr/bin/env bash
# Copy the harness into a target repo. Never overwrites: anything that already
# exists is reported and skipped, so re-running after a partial adopt is safe.
#
#   ./install.sh /path/to/repo
#
# Afterwards, the three things to answer are printed at the end.

set -euo pipefail

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEST=${1:-}

[ -n "$DEST" ] || { echo "usage: $0 /path/to/target-repo" >&2; exit 1; }
[ -d "$DEST" ] || { echo "not a directory: $DEST" >&2; exit 1; }
git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "not a git repo: $DEST — the harness uses git status as its signal" >&2; exit 1; }

copied=0 skipped=0

copy() { # $1 = path relative to template root
  local rel="$1" src="$SRC/$1" dst="$DEST/$1"
  if [ -e "$dst" ]; then
    printf '  skip    %s (exists)\n' "$rel"; skipped=$((skipped + 1)); return
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  printf '  copied  %s\n' "$rel"; copied=$((copied + 1))
}

echo "Installing harness into $DEST"
echo

for f in \
  .claude/harness.conf \
  .claude/settings.json \
  .claude/README.md \
  .claude/rules/primary.md \
  .claude/agents/implementer.md \
  .claude/skills/cook \
  .claude/hooks \
  scripts/goal.sh \
  docs/reference/architecture.md \
  docs/backlogs/plans/README.md \
  docs/backlogs/plans/_TEMPLATE.md \
  docs/backlogs/plans/_EXAMPLE \
  docs/backlogs/plans/active \
  docs/backlogs/plans/done \
  docs/backlogs/plans/archived \
  docs/backlogs/research \
  docs/backlogs/debug
do
  copy "$f"
done

chmod +x "$DEST"/.claude/hooks/*.sh "$DEST"/scripts/goal.sh 2>/dev/null || true

# CLAUDE.md is never overwritten — an existing one is the project's own.
if [ -e "$DEST/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md.template" "$DEST/CLAUDE.md.harness-template"
  echo "  note    CLAUDE.md exists — template left at CLAUDE.md.harness-template"
else
  cp "$SRC/CLAUDE.md.template" "$DEST/CLAUDE.md"
  echo "  copied  CLAUDE.md (from template)"
fi

# .gitignore: append only what is missing.
for line in '.claude/state' '__pycache__/'; do
  if ! grep -qxF "$line" "$DEST/.gitignore" 2>/dev/null; then
    echo "$line" >> "$DEST/.gitignore"
    echo "  added   .gitignore: $line"
  fi
done

echo
echo "copied $copied, skipped $skipped"
echo
cat <<'NEXT'
Three things to answer before the harness does anything for you:

  1. GATES — .claude/harness.conf
     The commands that mean "it works" here. Everything else in the harness is
     prose; these are the only thing that actually stops bad work. If you have
     no gate that fails on real breakage, fix that first.

  2. DOC_SYNC_CONTRACT_PATHS — .claude/harness.conf
     The paths where a change can break a documented contract. Until you set
     this, the doc-sync Stop hook is inert (it fails open by design).

  3. The Doc map — CLAUDE.md
     One row per code surface: what to read, what to update when it breaks.

Then verify:
  .claude/hooks/test-guard.sh      # the destructive-ops guard, 17 cases
  scripts/goal.sh                  # usage; `new <slug> "<title>"` starts a goal
NEXT
