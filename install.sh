#!/usr/bin/env bash
# install.sh - copy the factory template into a target repository.
#
#   ./install.sh              # install into the current directory
#   ./install.sh /path/repo   # install into a specific repo
#   ./install.sh --dry-run    # show what would happen
#   ./install.sh --with-issue-trigger /path/repo
#
# Never overwrites an existing file. Re-running is safe and reports what it skipped.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/template" && pwd)"
DRY=0
WITH_ISSUE_TRIGGER=0
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --with-issue-trigger) WITH_ISSUE_TRIGGER=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *)
      [ -z "$TARGET" ] || { echo "error: specify one target directory" >&2; exit 2; }
      TARGET="$arg"
      ;;
  esac
done

TARGET="${TARGET:-$PWD}"
[ -d "$TARGET" ] || { echo "error: no such directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "warning: $TARGET is not a git repository." >&2
  echo "         Cloud sessions clone from a GitHub remote, so the factory needs one." >&2
}

echo "factory template -> $TARGET"
[ "$DRY" -eq 1 ] && echo "(dry run)"
echo

COPIED=0; SKIPPED=0

copy() {
  local rel="$1" src="$SRC/$1" dst="$TARGET/$1"
  if [ -e "$dst" ]; then
    printf '  skip    %s (exists)\n' "$rel"; SKIPPED=$((SKIPPED+1)); return
  fi
  printf '  create  %s\n' "$rel"; COPIED=$((COPIED+1))
  [ "$DRY" -eq 1 ] && return
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# Walk the template. Files starting with a dot are included.
# Process substitution rather than a pipe, so the counters survive the loop.
while IFS= read -r rel; do
  if [ "$rel" = ".github/workflows/factory-fire.yml" ] && [ "$WITH_ISSUE_TRIGGER" -eq 0 ]; then
    continue
  fi
  copy "$rel"
done < <(cd "$SRC" && find . -type f | sed 's|^\./||' | sort)

if [ "$DRY" -eq 0 ]; then
  chmod +x "$TARGET/.claude/scripts/gates.sh"    2>/dev/null || true
  chmod +x "$TARGET/.claude/hooks/block-merge.sh" 2>/dev/null || true
  chmod +x "$TARGET/.factory/scripts/doctor.sh" 2>/dev/null || true
  chmod +x "$TARGET/.factory/scripts/bootstrap-github.sh" 2>/dev/null || true
  chmod +x "$TARGET/.factory/scripts/prove-test.sh" 2>/dev/null || true
fi

cat <<'EOF'

Next, in order:

  Setup guide: docs/factory/README.md

  1. docs/factory/CHARTER.md
     Set TIER, LOAD_BEARING globs, and AUTOMATABLE. This is the only step that
     decides what work the factory may attempt; set CHARTER_STATUS to ready only
     after reviewing every section.

  2. .factory/gates.conf and ./.claude/scripts/gates.sh full
     Confirm the required gates match this repo. Required skips produce
     MISCONFIGURED and block unattended work.

  3. CLAUDE.md
     Replace the <PROJECT NAME> header and the commands block. Keep the factory
     rules section as-is.

  4. Bootstrap and diagnose:
       ./.factory/scripts/bootstrap-github.sh        # preview labels
       ./.factory/scripts/bootstrap-github.sh --apply
       ./.factory/scripts/doctor.sh

     Configure a GitHub ruleset or branch protection for the default branch.
     Hooks are defense in depth and cannot replace repository-side enforcement.

  5. Commit and PUSH.
     Cloud sessions clone from the remote, not your local checkout.

  6. Local dry run:
       claude
       /factory
       "Run the factory-triage skill but report only. Write nothing."

  7. Cloud dry run:
       claude --cloud "Run the factory-triage skill and report what you would do.
                       Write nothing."

  8. Create routine 1 only. See ROUTINES.md. Let it run for a few days before
     adding the rest.

  The instant issue trigger is optional and is not installed by default. Re-run
  this installer with --with-issue-trigger if scheduled polling is too slow.
EOF

echo
echo "created: $COPIED   skipped: $SKIPPED"
