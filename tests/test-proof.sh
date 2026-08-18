#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/factory-proof-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.email factory-test@example.com
git -C "$fixture" config user.name "Factory Test"

printf 'old\n' > "$fixture/value.txt"
git -C "$fixture" add value.txt
git -C "$fixture" commit -qm base

mkdir -p "$fixture/tests"
printf 'new\n' > "$fixture/value.txt"
printf '%s\n' '#!/usr/bin/env bash' 'grep -qx new value.txt' > "$fixture/tests/value-test.sh"
chmod +x "$fixture/tests/value-test.sh"
git -C "$fixture" add value.txt tests/value-test.sh
git -C "$fixture" commit -qm change

proof_output="$(cd "$fixture" && "$ROOT/template/.factory/scripts/prove-test.sh" HEAD^ --test-path tests/value-test.sh -- bash tests/value-test.sh)"
printf '%s' "$proof_output" | grep -q 'status=PROVEN'
grep -qx new "$fixture/value.txt"
[ -z "$(git -C "$fixture" status --short)" ]

set +e
false_proof_output="$(cd "$fixture" && "$ROOT/template/.factory/scripts/prove-test.sh" HEAD^ --test-path tests/value-test.sh -- true 2>&1)"
false_proof_status=$?
set -e
[ "$false_proof_status" -eq 1 ]
printf '%s' "$false_proof_output" | grep -q 'status=FAILED'
grep -qx new "$fixture/value.txt"
[ -z "$(git -C "$fixture" status --short)" ]

echo "proof: ok"
