#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/factory-install.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
"$ROOT/install.sh" "$fixture" >/dev/null

for path in \
  CLAUDE.md \
  AGENTS.md \
  .factory/gates.conf \
  .factory/scripts/doctor.sh \
  .claude/scripts/gates.sh \
  .agents/skills/factory-implement/SKILL.md \
  .codex/hooks.json \
  docs/factory/CONTRACT.md \
  docs/factory/runs/README.md; do
  [ -e "$fixture/$path" ] || { echo "missing installed file: $path" >&2; exit 1; }
done

[ ! -e "$fixture/.github/workflows/factory-fire.yml" ] || {
  echo "optional issue trigger installed without flag" >&2
  exit 1
}

second_run="$($ROOT/install.sh "$fixture")"
printf '%s' "$second_run" | grep -q 'created: 0'

"$ROOT/install.sh" --with-issue-trigger "$fixture" >/dev/null
[ -f "$fixture/.github/workflows/factory-fire.yml" ]

set +e
"$ROOT/install.sh" --unknown "$fixture" >/dev/null 2>&1
unknown_status=$?
set -e
[ "$unknown_status" -eq 2 ]

echo "install: ok"
