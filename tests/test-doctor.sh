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
echo "doctor: ok"

