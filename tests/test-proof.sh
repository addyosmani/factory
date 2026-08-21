#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVE="$ROOT/template/.factory/scripts/prove-test.sh"
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
printf '%s\n' '#!/usr/bin/env bash' \
  'grep -qx new value.txt || { echo "AssertionError: value.txt is not new"; exit 1; }' \
  > "$fixture/tests/value-test.sh"
chmod +x "$fixture/tests/value-test.sh"
git -C "$fixture" add value.txt tests/value-test.sh
git -C "$fixture" commit -qm change

# A test that runs without the fix and fails an assertion is proof.
proof_output="$(cd "$fixture" && "$PROVE" HEAD^ --test-path tests/value-test.sh -- bash tests/value-test.sh)"
printf '%s' "$proof_output" | grep -q 'status=PROVEN'
grep -qx new "$fixture/value.txt"
[ -z "$(git -C "$fixture" status --short)" ]

# A test that still passes without the fix proves nothing.
set +e
false_proof_output="$(cd "$fixture" && "$PROVE" HEAD^ --test-path tests/value-test.sh -- true 2>&1)"
false_proof_status=$?
set -e
[ "$false_proof_status" -eq 1 ]
printf '%s' "$false_proof_output" | grep -q 'status=FAILED'
grep -qx new "$fixture/value.txt"
[ -z "$(git -C "$fixture" status --short)" ]

# A non-zero exit alone is not proof: a test that could not load says nothing
# about whether it asserts anything.
set +e
load_output="$(cd "$fixture" && "$PROVE" HEAD^ --test-path tests/value-test.sh -- \
  bash -c 'echo "ModuleNotFoundError: No module named \"thing\""; exit 1' 2>&1)"
load_status=$?
set -e
[ "$load_status" -eq 3 ]
printf '%s' "$load_output" | grep -q 'status=UNPROVEN reason=test-could-not-load'

# A failure the script cannot classify fails closed too.
set +e
silent_output="$(cd "$fixture" && "$PROVE" HEAD^ --test-path tests/value-test.sh -- false 2>&1)"
silent_status=$?
set -e
[ "$silent_status" -eq 3 ]
printf '%s' "$silent_output" | grep -q 'status=UNPROVEN reason=failure-not-classified'
[ -z "$(git -C "$fixture" status --short)" ]

# Real runner output must classify the same way across the stacks the gates support.
# The classifier is the whole of the new signal, so it is worth pinning to samples.
classify_case() {
  local expect="$1" label="$2" output="$3" got status
  set +e
  got="$(cd "$fixture" && "$PROVE" HEAD^ --test-path tests/value-test.sh -- \
    bash -c "printf '%s\n' \"\$1\"; exit 1" _ "$output" 2>&1)"
  status=$?
  set -e
  printf '%s' "$got" | grep -q "status=$expect" || {
    echo "classify($label): expected $expect, got: $(printf '%s' "$got" | grep '^PROOF:')" >&2
    exit 1
  }
}

classify_case PROVEN   'pytest assertion'   'FAILED tests/test_a.py::test_x - assert 3 == 4
1 failed in 0.02s'
classify_case UNPROVEN 'pytest collection'  'E   ModuleNotFoundError: No module named "src.slug"
!!!! Interrupted: 1 error during collection !!!!'
classify_case PROVEN   'jest assertion'     'expect(received).toBe(expected)
Tests:       1 failed, 0 passed'
classify_case UNPROVEN 'jest missing module' 'Test suite failed to run
Cannot find module "./slug" from "src/a.test.js"'
classify_case PROVEN   'go assertion'       '--- FAIL: TestAdd (0.00s)'
classify_case UNPROVEN 'go build failure'   'FAIL	example/pkg [build failed]'
classify_case PROVEN   'cargo assertion'    'test result: FAILED. 0 passed; 1 failed'
classify_case UNPROVEN 'cargo compile'      'error: could not compile `demo`'
[ -z "$(git -C "$fixture" status --short)" ]

# Default patterns must recognise pytest's co-located layout, or the new test is
# bundled into the revert and deleted along with the implementation.
colocated="$(mktemp -d "${TMPDIR:-/tmp}/factory-proof-colocated.XXXXXX")"
trap 'rm -rf "$fixture" "$colocated"' EXIT
git -C "$colocated" init -q
git -C "$colocated" config user.email factory-test@example.com
git -C "$colocated" config user.name "Factory Test"
mkdir -p "$colocated/src/utils"
printf 'old\n' > "$colocated/src/utils/value.txt"
git -C "$colocated" add src/utils/value.txt
git -C "$colocated" commit -qm base
printf 'new\n' > "$colocated/src/utils/value.txt"
printf '%s\n' '#!/usr/bin/env bash' \
  'grep -qx new src/utils/value.txt || { echo "AssertionError: not new"; exit 1; }' \
  > "$colocated/src/utils/test_value.sh"
git -C "$colocated" add -A
git -C "$colocated" commit -qm change
colocated_output="$(cd "$colocated" && "$PROVE" HEAD^ -- bash src/utils/test_value.sh)"
printf '%s' "$colocated_output" | grep -q 'status=PROVEN'
[ -f "$colocated/src/utils/test_value.sh" ]

# The default-pattern path must not trip over an empty array under bash 3.2.
if [ -x /bin/bash ]; then
  (cd "$colocated" && /bin/bash "$PROVE" HEAD^ -- bash src/utils/test_value.sh) \
    | grep -q 'status=PROVEN'
fi

echo "proof: ok"
