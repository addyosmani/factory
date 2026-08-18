# Factory decisions

Why the factory is configured the way it is. Written by a human, informed by
`/factory-tune`.

This file exists so a future tuning pass can tell whether a past loosening was a mistake.
Without it, every constraint review starts from scratch and the same argument gets had
twice a year.

Newest at the top.

---

## Template

### 2026-08-16 - <what changed>

**Change:** <the specific rule, before and after>

**Evidence:** <the run of data. "23 dependency bumps over 6 weeks, zero escapes" is
evidence. "It seemed fine" is not.>

**Risk accepted:** <what this makes more likely, stated plainly>

**Revisit if:** <the observation that would reverse this>

---

## Seed entries

### 2026-08-16 - Merge is never automated, on any tier

**Change:** No routine or session may merge, on any tier including `revival`. Enforced by a
GitHub ruleset or branch protection. Harness hooks block common shell routes as a second
layer.

**Evidence:** Structural rather than empirical. The merge decision is where accountability
lives, and it is the one point where a human takes responsibility for consequences.

**Risk accepted:** Throughput is capped by human review availability. This is intentional.
The binding constraint on a factory is decisions pending judgment, not agents running.

**Revisit if:** Never, at any tier.

---

### 2026-08-16 - Verification is a separate agent from implementation

**Change:** `factory-implement` must delegate to the `factory-verifier` subagent and may
not self-certify.

**Evidence:** An agent asked to check its own work grades the intent it already had. The
separation is the only thing that makes a green result mean anything.

**Risk accepted:** Roughly doubles token cost per item. Worth it.

**Revisit if:** Never. Tune the verifier's strictness instead.

---

### 2026-08-16 - Unattended runs may not modify existing test files

**Change:** An unattended run stops before modifying a pre-existing test file. An
interactive session requires explicit human approval, stays draft, and receives a human
read regardless of gate status.

**Evidence:** Agents can rewrite assertions to match broken behavior. An unexplained green
suite after the implementation agent changed the tests is weak evidence and can be
invisible to ordinary automated checks because everything passes.

**Risk accepted:** Legitimate test refactors need a human. Acceptable.

**Revisit if:** Never, while the gates depend on the tests being trustworthy.
