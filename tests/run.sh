#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

while IFS= read -r script; do
  bash -n "$script"
done < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)

python3 -m json.tool template/.claude/settings.json >/dev/null
python3 -m json.tool template/.codex/hooks.json >/dev/null

for test_script in tests/test-*.sh; do
  printf '\n==> %s\n' "$test_script"
  bash "$test_script"
done

printf '\nAll factory tests passed.\n'

