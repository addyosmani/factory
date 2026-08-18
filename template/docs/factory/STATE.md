# Factory state snapshot

Human-readable summary of the latest known factory state. Routines do not append here.
Each run writes a unique file under `docs/factory/runs/`, and `/factory` reads those records
along with live GitHub labels.

This file can be refreshed deliberately when a compact summary is useful. It is not a
coordination lock and may be stale while run-record PRs are still open.

**Run records include what was checked and found clean, not only findings.** A silent record
is ambiguous between "nothing was wrong" and "the check never ran".

---

## Example snapshot (replace during setup)

- last successful triage: none
- last successful monitor: none
- ready to implement: 0
- in progress: 0
- awaiting review: 0
- charter gaps: none known

---
