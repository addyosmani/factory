#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$ROOT/template/.claude/hooks/block-merge.sh"

# blocked <command>  - the hook must exit 2 and refuse the call.
blocked() {
  set +e
  printf '{"tool_input":{"command":"%s"}}\n' "$1" | bash "$hook" >/dev/null 2>&1
  local status=$?
  set -e
  [ "$status" -eq 2 ] || { echo "expected block: $1" >&2; exit 1; }
}

# allowed <command>  - the hook must not stand in the way.
allowed() {
  set +e
  printf '{"tool_input":{"command":"%s"}}\n' "$1" | bash "$hook" >/dev/null 2>&1
  local status=$?
  set -e
  [ "$status" -eq 0 ] || { echo "expected allow: $1" >&2; exit 1; }
}

allowed 'git status'
blocked 'gh pr merge 42 --squash'

# Every spelling of a push whose destination is a protected branch.
blocked 'git push origin main'
blocked 'git push origin HEAD:main'
blocked 'git push origin +main'
blocked 'git push origin mybranch:main'
blocked 'git push origin --delete main'
blocked 'git push origin +refs/heads/main'

# A + refspec is a force push wherever it points, including at a claim branch.
blocked 'git push origin +claude/fq-3'

# Claiming and releasing a claim branch must still work.
allowed 'git push origin HEAD:refs/heads/claude/fq-3'
allowed 'git push origin --delete claude/fq-3'

# Protected policy files, including the proof script the verifier depends on.
blocked 'printf x > .factory/gates.conf'
blocked 'rm .claude/hooks/block-merge.sh'
blocked 'rm -rf .claude'

# Running a protected script and capturing its output is not writing to it.
allowed './.claude/scripts/gates.sh full > /tmp/factory-gates.log'
allowed 'echo note > docs/factory/runs/run.md'

echo "hook: ok"
