#!/usr/bin/env bash
set -euo pipefail

command -v node >/dev/null 2>&1 || { echo "gates: skipped (node unavailable)"; exit 0; }
command -v npm >/dev/null 2>&1 || { echo "gates: skipped (npm unavailable)"; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/factory-gates.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
git -C "$fixture" init -q
"$ROOT/install.sh" "$fixture" >/dev/null

write_package() {
  local test_command="$1"
  if [ "$test_command" = "missing" ]; then
    apply_content='{
      "private": true,
      "scripts": {"typecheck": "true", "lint": "true"}
    }'
  else
    apply_content="{\n  \"private\": true,\n  \"scripts\": {\"typecheck\": \"true\", \"lint\": \"true\", \"test\": \"$test_command\"}\n}"
  fi
  printf '%b\n' "$apply_content" > "$fixture/package.json"
}

write_package true
green_output="$(cd "$fixture" && ./.claude/scripts/gates.sh full)"
printf '%s' "$green_output" | grep -q 'status=GREEN'

set +e
invalid_output="$(cd "$fixture" && ./.claude/scripts/gates.sh typo 2>&1)"
invalid_status=$?
set -e
[ "$invalid_status" -eq 2 ]
printf '%s' "$invalid_output" | grep -q 'status=MISCONFIGURED'

write_package missing
set +e
missing_output="$(cd "$fixture" && ./.claude/scripts/gates.sh full 2>&1)"
missing_status=$?
set -e
[ "$missing_status" -eq 2 ]
printf '%s' "$missing_output" | grep -q 'status=MISCONFIGURED'
printf '%s' "$missing_output" | grep -q 'misconfigured=test'

write_package false
set +e
red_output="$(cd "$fixture" && ./.claude/scripts/gates.sh full 2>&1)"
red_status=$?
set -e
[ "$red_status" -eq 1 ]
printf '%s' "$red_output" | grep -q 'status=RED'

echo "gates: ok"

