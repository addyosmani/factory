#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/factory-doctor.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
"$ROOT/install.sh" "$fixture" >/dev/null

set +e
(cd "$fixture" && ./.factory/scripts/doctor.sh >/dev/null)
incomplete_status=$?
set -e
[ "$incomplete_status" -ne 0 ]

sed -i.bak 's/# <PROJECT NAME>/# Test project/; s/<One paragraph: what this is and who depends on it.>/A test fixture./; s/<install>/true/' "$fixture/CLAUDE.md"
sed -i.bak 's/CHARTER_STATUS: incomplete/CHARTER_STATUS: ready/; s/TIER: <choose one tier>/TIER: greenfield/' "$fixture/docs/factory/CHARTER.md"
rm -f "$fixture/CLAUDE.md.bak" "$fixture/docs/factory/CHARTER.md.bak"

(cd "$fixture" && ./.factory/scripts/doctor.sh >/dev/null)

# install.sh refuses to overwrite, so a repo that already had .claude/settings.json
# ends up installed but unguarded. Doctor must not call that healthy.
mv "$fixture/.claude/settings.json" "$fixture/.claude/settings.json.saved"
printf '{"permissions":{"allow":[],"deny":[]}}\n' > "$fixture/.claude/settings.json"
set +e
(cd "$fixture" && ./.factory/scripts/doctor.sh > "$fixture/unguarded.log" 2>&1)
unguarded_status=$?
set -e
[ "$unguarded_status" -ne 0 ]
grep -q 'block-merge.sh is not wired' "$fixture/unguarded.log"
grep -q 'missing from the Edit deny list' "$fixture/unguarded.log"
mv "$fixture/.claude/settings.json.saved" "$fixture/.claude/settings.json"

(cd "$fixture" && ./.factory/scripts/doctor.sh >/dev/null)
echo "doctor: ok"

