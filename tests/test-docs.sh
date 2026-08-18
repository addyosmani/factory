#!/usr/bin/env bash
# Check that repository-relative Markdown links resolve.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
from urllib.parse import unquote, urlparse
import re
import sys

root = Path(sys.argv[1]).resolve()
pattern = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
failures = []

for document in sorted(root.rglob("*.md")):
    if ".git" in document.parts:
        continue

    text = document.read_text(encoding="utf-8")
    for raw_target in pattern.findall(text):
        target = raw_target.strip().strip("<>")
        parsed = urlparse(target)
        if parsed.scheme or target.startswith(("#", "mailto:")):
            continue

        path_part = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not path_part:
            continue

        resolved = (document.parent / path_part).resolve()
        if not resolved.exists():
            try:
                expected = resolved.relative_to(root)
            except ValueError:
                expected = resolved
            failures.append(
                f"{document.relative_to(root)} -> {target} (expected {expected})"
            )

if failures:
    print("Broken repository-relative Markdown links:", file=sys.stderr)
    for failure in failures:
        print(f"  {failure}", file=sys.stderr)
    raise SystemExit(1)

print("docs: ok")
PY
