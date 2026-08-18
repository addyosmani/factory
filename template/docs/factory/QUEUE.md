# Factory queue snapshot

The operational queue lives in GitHub issue labels. This file is a reviewable snapshot
written by `factory-triage` and reported by `/factory`; implementation routines query
GitHub directly.

An unmerged update to this file must never block a later routine from seeing work. Durable
run evidence lives in one file per run under `docs/factory/runs/`.

**Dispositions**

| Disposition | Next stage |
|---|---|
| `ready-to-implement` | factory-implement picks it up |
| `ready-to-spec` | human runs factory-spec |
| `needs-info` | parked, question is on the issue |
| `wait-to-implement` | parked, blocker named below |
| `awaiting-review` | PR open, human owns it |
| `done` | merged by a human |

The corresponding live labels use the `factory:` prefix, for example
`factory:ready-to-implement` and `factory:awaiting-review`. The live issue also carries a
`factory-handoff:v1` comment with the fields needed by implementation.

---

## Example entry (delete this)

## FQ-142: Expired tokens return 500 instead of 401
- disposition: ready-to-implement
- source: https://github.com/owner/repo/issues/142
- last_triaged: 2026-08-16
- repro: confirmed
- files_expected: src/auth/verify.ts, src/auth/verify.test.ts
- load_bearing: true
- gate_level: deep
- done_when: `verify.test.ts` has a case for an expired token asserting a 401 response, it fails on `main`, and it passes after the change
- confidence: high
- notes: `src/auth/**` is load-bearing, so this cannot be auto-implemented despite being simple. Route through factory-spec or implement with a forced human read.

---
