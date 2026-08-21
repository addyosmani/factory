#!/usr/bin/env bash
# Prove that a test fails when the non-test portion of a committed change is removed.
# The working tree must be clean. The script restores it even when the test command fails.
#
# A non-zero exit from the reverted run is not by itself proof. Reverting deletes new
# implementation files, so a test that only imports the new module fails to load whether
# or not it asserts anything. This script classifies the failure and only reports PROVEN
# when the test actually ran and failed.
#
# Usage:
#   ./.factory/scripts/prove-test.sh <base-ref> --test-path <path> -- <test command...>
#
# Exit codes:
#   0  PROVEN       the test ran without the fix and failed
#   1  FAILED       the test passed without the fix; it proves nothing
#   2  MISCONFIGURED bad arguments, dirty tree, or nothing to revert
#   3  UNPROVEN     the run failed in a way that does not demonstrate the test asserts
#                   anything (it could not load, or the failure could not be classified)

set -euo pipefail

BASE="${1:-}"
if [ -z "$BASE" ]; then
  echo "usage: $0 <base-ref> [--test-path <path>]... -- <test command...>" >&2
  exit 2
fi
shift

test_paths=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
  if [ "$1" != "--test-path" ] || [ "$#" -lt 2 ]; then
    echo "usage: $0 <base-ref> [--test-path <path>]... -- <test command...>" >&2
    exit 2
  fi
  test_paths+=("$2")
  shift 2
done

if [ "${1:-}" != "--" ] || [ "$#" -lt 2 ]; then
  echo "usage: $0 <base-ref> [--test-path <path>]... -- <test command...>" >&2
  exit 2
fi
shift

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "PROOF: status=MISCONFIGURED reason=not-a-git-repository" >&2
  exit 2
}
cd "$ROOT"

git rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || {
  echo "PROOF: status=MISCONFIGURED reason=invalid-base-ref base=$BASE" >&2
  exit 2
}

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "PROOF: status=MISCONFIGURED reason=working-tree-not-clean" >&2
  exit 2
fi

patch_file="$(mktemp "${TMPDIR:-/tmp}/factory-proof.XXXXXX.patch")"
output_file=""
reverted=0

restore() {
  if [ -n "$output_file" ]; then rm -f "$output_file"; fi
  if [ "$reverted" -eq 1 ] && [ -s "$patch_file" ]; then
    git apply "$patch_file" >/dev/null 2>&1 || {
      echo "PROOF: restore failed; patch retained at $patch_file" >&2
      return
    }
  fi
  rm -f "$patch_file"
}
trap restore EXIT INT TERM

non_test_files=()
while IFS= read -r -d '' path; do
  is_test=0
  if [ "${#test_paths[@]}" -eq 0 ]; then
    # Default patterns. `test_*` and `spec_*` are repeated with a `*/` prefix so
    # pytest's co-located layout (src/utils/test_foo.py) is recognised as a test.
    case "$path" in
      test/*|tests/*|*/test/*|*/tests/*|*/__tests__/*|*.test.*|*.spec.*) is_test=1 ;;
      test_*|*/test_*|spec_*|*/spec_*|*_test.*|*_spec.*)                 is_test=1 ;;
    esac
  else
    # Expanded through the `+` form: an empty array is an error under `set -u`
    # on bash 3.2, which is /bin/bash on macOS.
    for test_path in ${test_paths[@]+"${test_paths[@]}"}; do
      if [ "$path" = "$test_path" ] || [[ "$path" == "$test_path"/* ]]; then
        is_test=1
        break
      fi
    done
  fi
  [ "$is_test" -eq 1 ] || non_test_files+=("$path")
done < <(git diff --name-only -z "$BASE"...HEAD)

if [ "${#non_test_files[@]}" -eq 0 ]; then
  echo "PROOF: status=MISCONFIGURED reason=no-non-test-change" >&2
  exit 2
fi

git diff --binary "$BASE"...HEAD -- "${non_test_files[@]}" > "$patch_file"
if [ ! -s "$patch_file" ]; then
  echo "PROOF: status=MISCONFIGURED reason=empty-revert-patch" >&2
  exit 2
fi

output_file="$(mktemp "${TMPDIR:-/tmp}/factory-proof.XXXXXX.log")"

git apply -R "$patch_file"
reverted=1

set +e
"$@" 2>&1 | tee "$output_file"
test_status="${PIPESTATUS[0]}"
set -e

git apply "$patch_file"
reverted=0

if [ "$test_status" -eq 0 ]; then
  echo "PROOF: status=FAILED reason=test-passed-without-fix"
  exit 1
fi

# Classify the failure. Load failures are checked first: when a test cannot even be
# collected, the run says nothing about whether it contains an assertion.
signal="unclassified"
if grep -qiE 'modulenotfounderror|importerror|cannot find module|cannot resolve|failed to resolve import|error[s]? during collection|test suite failed to run|no tests (ran|found|to run)|collected 0 items|cannot find package|build failed|unresolved import|could not compile|syntaxerror|referenceerror|typeerror: .* is not a function|nameerror|command not found' "$output_file"; then
  signal="load"
elif grep -qiE 'assertionerror|assertion failed|assertion .* failed|--- fail:|test result: failed|panicked at|[0-9]+ (test[s]? )?failed|failed: *[1-9]|failures[=:] *[1-9]|^fail [1-9]|(^|[^a-z])fail(ed)?[^a-z].*(test|spec)|✕|✖|×|expect(ed)?[( ]' "$output_file"; then
  signal="assertion"
fi

case "$signal" in
  assertion)
    echo "PROOF: status=PROVEN signal=assertion test_exit=$test_status"
    ;;
  load)
    echo "PROOF: status=UNPROVEN reason=test-could-not-load test_exit=$test_status"
    echo "PROOF: the reverted run failed before the test executed, so this does not show the test asserts anything." >&2
    exit 3
    ;;
  *)
    echo "PROOF: status=UNPROVEN reason=failure-not-classified test_exit=$test_status"
    echo "PROOF: the reverted run failed but the output did not identify an assertion failure." >&2
    exit 3
    ;;
esac
