#!/usr/bin/env bash
set -euo pipefail

fixture="$(mktemp -d "${TMPDIR:-/tmp}/factory-claim.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git init -q --bare "$fixture/remote.git"
git clone -q "$fixture/remote.git" "$fixture/seed" 2>/dev/null
git -C "$fixture/seed" config user.email factory-test@example.com
git -C "$fixture/seed" config user.name "Factory Test"
printf 'base\n' > "$fixture/seed/README.md"
git -C "$fixture/seed" add README.md
git -C "$fixture/seed" commit -qm base
git -C "$fixture/seed" push -q origin HEAD:main
git -C "$fixture/remote.git" symbolic-ref HEAD refs/heads/main

git clone -q "$fixture/remote.git" "$fixture/runner-a"
git clone -q "$fixture/remote.git" "$fixture/runner-b"

for runner in runner-a runner-b; do
  git -C "$fixture/$runner" config user.email factory-test@example.com
  git -C "$fixture/$runner" config user.name "Factory Test"
  git -C "$fixture/$runner" switch -qc claude/fq-142
  git -C "$fixture/$runner" commit -q --allow-empty -m "factory: claim $runner"
done

git -C "$fixture/runner-a" push -q origin HEAD:refs/heads/claude/fq-142
set +e
git -C "$fixture/runner-b" push -q origin HEAD:refs/heads/claude/fq-142 >/dev/null 2>&1
second_status=$?
set -e

[ "$second_status" -ne 0 ]
echo "claim: ok"
