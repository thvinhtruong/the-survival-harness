#!/usr/bin/env bash
# Copy the harness into a target repo. Never overwrites: anything that already
# exists is reported and skipped, so re-running after a partial adopt is safe.
#
#   ./install.sh /path/to/repo
#
# Afterwards, the things to answer are printed at the end.

set -euo pipefail

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEST=${1:-}

[ -n "$DEST" ] || { echo "usage: $0 /path/to/target-repo" >&2; exit 1; }
[ -d "$DEST" ] || { echo "not a directory: $DEST" >&2; exit 1; }
git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "not a git repo: $DEST — the harness uses git as its signal" >&2; exit 1; }
command -v jq >/dev/null 2>&1 \
  || echo "warning: jq not found — scripts/goal refuses to run and the JSON hooks fail open until it is installed" >&2

copied=0 skipped=0

copy() { # $1 = path relative to template root
  local rel="$1" src="$SRC/$1" dst="$DEST/$1" f
  # Directories go file by file: an existing .claude/hooks/ must not make the
  # whole harness hook set skip, or settings.json points at scripts that are
  # not there and every guard fails open.
  if [ -d "$src" ]; then
    while IFS= read -r f; do copy "${f#"$SRC"/}"; done < <(find "$src" -type f | sort)
    return
  fi
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
  .claude/agents/navigator.md \
  .claude/agents/researcher.md \
  .claude/skills/cook \
  .claude/skills/debug \
  .claude/skills/gap-audit \
  .claude/skills/verify \
  .claude/skills/api-lookup \
  .claude/hooks \
  scripts/goal \
  scripts/gate-record.sh \
  scripts/skip.sh \
  docs/backlogs/goals/README.md \
  docs/backlogs/goals/_EXAMPLE.jsonl \
  docs/backlogs/debug \
  docs/backlogs/research
do
  copy "$f"
done

chmod +x "$DEST"/.claude/hooks/*.sh "$DEST"/scripts/goal "$DEST"/scripts/gate-record.sh \
  "$DEST"/scripts/skip.sh 2>/dev/null || true

# CLAUDE.md is never overwritten — an existing one is the project's own.
if [ -e "$DEST/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md.template" "$DEST/CLAUDE.md.harness-template"
  echo "  note    CLAUDE.md exists — template left at CLAUDE.md.harness-template"
else
  cp "$SRC/CLAUDE.md.template" "$DEST/CLAUDE.md"
  echo "  copied  CLAUDE.md (from template)"
fi

# .gitignore: append only what is missing.
for line in '.claude/state' '.claude/scheduled_tasks.lock' '__pycache__/'; do
  if ! grep -qxF "$line" "$DEST/.gitignore" 2>/dev/null; then
    echo "$line" >> "$DEST/.gitignore"
    echo "  added   .gitignore: $line"
  fi
done

echo
echo "copied $copied, skipped $skipped"
echo
cat <<'NEXT'
Four things to answer before the harness does anything for you:

  1. GATES — .claude/harness.conf, and the Makefile
     The make targets that mean "it works" here. Each recipe's LAST line must
     record the pass against the tree it ran on:

         .PHONY: lint test
         lint:
         	<your linters / type-check / build>
         	@scripts/gate-record.sh lint

     Every gate must be .PHONY — a same-named directory (build/, test/) makes
     make skip the recipe and exit 0, so the gate "passes" without running.
     No `-` prefix or `|| true` on a gate line: it would record a failed pass.

     These gates are the only thing that actually stops bad work — if none
     fails on real breakage, fix that first.

  2. DOC_SYNC_CONTRACT_PATHS — .claude/harness.conf
     The paths where a change can break a documented contract. Until you set
     this, the doc-sync Stop hook is inert (it fails open by design).

  3. GENERATED_FILES — .claude/harness.conf
     Files that are regenerated, never hand-edited. Edit/Write on them is denied.
     The guard only stops hand-edits — add each generator's `--check` step to
     a gate (e.g. lint) so a stale file fails too.

     Optional: BROWSER_VERIFY_SKILL — fill .claude/skills/verify/SKILL.md.template,
     rename it to SKILL.md, and set BROWSER_VERIFY_SKILL="verify".

     Optional: API_SPEC — if you generate an OpenAPI 3 JSON spec, set its path
     and rename .claude/skills/api-lookup/SKILL.md.template to SKILL.md.

  4. The Doc map — CLAUDE.md
     One row per code surface: what to read, what to update when it breaks.

Then verify:
  .claude/hooks/test-guard.sh      # syntax sweep + every guard's allow/deny cases
  scripts/goal                     # usage; `new <slug> "<title>"` starts a goal
NEXT
