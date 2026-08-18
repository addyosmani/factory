#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$ROOT/template/.claude/hooks/block-merge.sh"

printf '%s\n' '{"tool_input":{"command":"git status"}}' | bash "$hook"

set +e
printf '%s\n' '{"tool_input":{"command":"gh pr merge 42 --squash"}}' | bash "$hook" >/dev/null 2>&1
merge_status=$?
printf '%s\n' '{"tool_input":{"command":"printf x > .factory/gates.conf"}}' | bash "$hook" >/dev/null 2>&1
policy_status=$?
set -e

[ "$merge_status" -eq 2 ]
[ "$policy_status" -eq 2 ]

echo "hook: ok"

