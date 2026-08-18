# Architecture

Why this is shaped the way it is, what it borrows, and where it deliberately departs.

---

## The bet

**Everything the factory needs lives in the repository.**

Cloud sessions start from a fresh clone. Whatever is committed is available; whatever lives
only on your machine is not. That single fact determines the entire design:

| Committed, works everywhere | Machine-local, invisible to cloud |
|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `.claude/skills/`, `agents/`, `commands/`, `rules/` | `~/.claude/skills/` etc. |
| `.claude/settings.json` and its hooks | user-scoped `enabledPlugins` |
| `AGENTS.md`, `.agents/skills/`, `.codex/hooks.json` | user-scoped Codex instructions and skills |
| `docs/factory/CONTRACT.md`, `.factory/` | shell history and uncommitted local scripts |
| `.mcp.json` (project scope) | `claude mcp add` at local or user scope |
| `docs/factory/*` | anything in your shell history |

The shared contract, gates, queue labels, and run records drive both harnesses. Claude Code
adds cloud routines and sessions; Codex adds project instructions, repo skills, and trusted
hooks. There is no second policy document to keep in sync.

The one exception is the cloud environment itself (network, env vars, setup script) and the
routine definitions. Those are account-level UI state. See [LIMITS.md](LIMITS.md) §2.

---

## Mapping to the factory loop

A useful end-to-end loop is `triage → spec → implement → review → verify → ship → monitor`.
Here is what each stage is built from, using only stock parts.

| Stage | Mechanism | Surface | Human? |
|---|---|---|---|
| Triage | `factory-triage` skill + scheduled routine | Cloud | Reads the snapshot PR |
| Spec | `factory-spec` skill, four explicit gates | **Desktop, interactive** | **Approves each gate** |
| Implement | `factory-implement` skill + scheduled routine or `--cloud` | Cloud | No |
| Review | `factory-verifier` subagent, in-session | Cloud | No |
| Verify | `factory-verify` skill + `pull_request.opened` routine | Cloud | No |
| Ship | **Human merges.** Enforced by repository branch rules | Anywhere | **Yes, always** |
| Monitor | `factory-monitor` skill + weekly routine | Cloud | Reads findings |

Two stages are deliberately not automatable. Spec is where product intent and system shape
get decided, and those are the judgments that no oracle grades. Ship is where accountability
lives.

---

## Where this reference deliberately departs

Organization-scale factory designs usually optimize for governance, cost control, and
reducing variability across many developers. Those are sensible priorities for that audience.

A personal or small-team factory has a different binding constraint. There is one human, so
variability is not the problem. The problem is that **one person's review attention is the
entire quality apparatus, with no organizational backstop behind it** - no review culture,
no SRE, no second pair of eyes that catches things by accident.

Four consequences:

**1. No orchestrator.** Routines already provide schedule, API, and GitHub triggers on
managed infrastructure. A queue service, Temporal, or a custom worker adds operational
surface to maintain and buys nothing until you need triggers routines do not have.

**2. Thin harness adapters, no orchestration abstraction.** Claude Code is the primary
execution path. Codex gets `AGENTS.md`, repo-scoped skill wrappers, and a hook adapter, all
pointing at the same contract and workflows. We do not hide either harness behind a custom
SDK or invent a lowest-common-denominator agent API.

**3. Deterministic gates matter more, not less.** Without an org behind you, `gates.sh` is
not a supplement to the quality system, it *is* the quality system. And at N parallel
sessions the gates run N times while you read a fraction of one, which makes them most of
the review surface rather than a check on it.

**4. Back-pressure is a hard number, not a principle.** The charter's `STOP_IF` review-queue
limit makes the factory stop producing when too many decisions are pending. This is the one
piece of the design that actively refuses work, and it is the piece most likely to be
deleted by someone optimizing for throughput.

---

## The five design rules

Everything else follows from these.

### 1. Judgment upstream, in a file

`docs/factory/CHARTER.md` is the primary human-owned policy file and one an agent may never
edit on its own initiative. It encodes tier, load-bearing paths, what is automatable,
definition of done, and stop conditions.

Every skill reads it first. **If the charter does not cover something, the answer is stop.**
Silence means stop, not proceed. Default-deny is what keeps scope from drifting one
reasonable-looking inference at a time.

### 2. Autonomy tracks consequence, not difficulty

Four tiers, and the relationship is inverted from what people expect:

| Tier | Autonomy | Typical volume |
|---|---|---|
| `revival` (unlaunched migrations) | Widest | **Largest** |
| `greenfield` | Wide | Large |
| `oss` | Moderate | Medium |
| `client-production` | Narrowest | **Smallest** |

The tier that changes the most code gets the most autonomy; the tier that changes the least
gets the least. A ten-thousand-line migration on an unlaunched project is a safer bet than a
fifty-line change to a client's auth path.

**Tier-bleed is the real risk**, and it is specific to running several tiers in one day.
Spend a morning on a migration where accepting a hundred unread green diffs is correct, then
switch to a client repo in the afternoon, and the "green means merge" reflex comes with you.
Same terminal, same agent, same checkmarks, nothing signals the change.

That is why the constraint lives in `docs/factory/CONTRACT.md`, with small Claude and Codex
adapters **inside each repo**, rather than in your habits. When a person moves between risk
contexts many times a day, the context has to carry the constraint.

### 3. The gate script is the verdict

`gates.sh` ends with a line no agent may paraphrase:

```
FACTORY_GATES: level=full status=RED passed=3 failed=1 failing=test skipped=build misconfigured=none
```

Skills must quote it verbatim and may not report a result that contradicts it. This exists
because an agent can argue a human into a merge and cannot argue a type checker into
anything. In a system where the generator is fluent and confident and reviewer attention is
scarce, the incorruptible checks are the only ones whose verdict survives contact with a
persuasive PR description.

Three tiers, because a gate too slow to run constantly does not get run:

- `fast` - types and lint by default. Seconds.
- `full` - plus tests; build runs when configured. The default before any PR.
- `deep` - plus audit and architecture rules; mutation runs when configured.

Required gates are declared in `.factory/gates.conf`. A required `SKIP` returns
`MISCONFIGURED` with exit 2. Optional skips remain visible for the human to review.

### 4. The writer never grades the work

`factory-implement` must delegate to the `factory-verifier` subagent, which reads the diff
cold, re-runs the gates itself, and is explicitly told to **ignore any narrative** of what
was implemented.

Its highest-value check is one no deterministic gate can make: revert the non-test hunks and
confirm the test actually fails without the fix. A test that passes with the implementation
removed is worse than no test, because it is actively misleading.

Standing bias is reject-when-uncertain. A false accept is worse than no verification: it
spends a human's trust that was never earned, and they read the next one less carefully.

`factory-critic` is a second, different lens for load-bearing changes. Not redundancy -
diversity. Across 146 PRs and four review tools, 93.4% of findings were caught by exactly
one of the four and none by all four. Two reviewers with different failure modes beat one
good one, which is also why the critic is told not to re-run the gates.

### 5. Operational state has one owner

GitHub issue labels are the live queue. `QUEUE.md` and `STATE.md` are snapshots,
`DECISIONS.md` and `specs/` preserve human reasoning, and `runs/` contains one immutable
record per execution.

On one repo you can carry state in your head between sessions. Across a portfolio you
cannot, and these files are what let a run be resumed by a person who has been thinking
about something else for six hours. They are also the only durable record after the
transcripts are gone, which on client work is the difference between a maintainable handover
and a cliff.

---

## Enforcement: instruction versus structure

The repository contract tells an agent not to merge. GitHub branch protection or a ruleset
enforces that boundary. `.claude/hooks/block-merge.sh` and `.codex/hooks.json` add a useful
second layer for local shell commands.

The hook is a `PreToolUse` matcher on `Bash` that blocks `gh pr merge`, `git merge`, force
pushes, pushes to protected branches, and shell writes to protected factory files. Exit code
2 blocks the call and returns the reason to the agent.

Hooks do not cover every hosted tool, API path, or specialized tool implementation. Treat
them as a guardrail, not a security boundary. This distinction matters most during
unattended runs, when there is no human approval prompt to catch an alternate path.

Belt and braces: `settings.json` also denies `Edit` on the charter and gate script, and the
hook additionally blocks routing around those denials via `sed`, `tee`, or shell redirection.

---

## Failure modes this design targets

| Failure | Where it is addressed |
|---|---|
| Agent rewrites test assertions to go green | Charter rule, implement prohibition, verifier check |
| Test passes without the implementation | Verifier reverts and re-runs |
| Green gates, changed behavior (migrations) | `factory-spec` requires naming the oracle first |
| Scope creep into an unreviewable diff | `files_expected`, line limit, verifier scope check |
| Comprehension debt | `done_when`, PR "why this is safe", `DECISIONS.md` |
| Review queue silently overflowing | `STOP_IF` limit; implement routine refuses to start |
| Tier-bleed between client and greenfield work | Per-repo charter, settings, and hook |
| Silent truncation reading as full coverage | Every skill must state what it dropped |
| Constraints drifting into tax or hole | `/factory-tune` on a schedule, evidence in `DECISIONS.md` |

---

## Migrations get their own treatment

`factory-spec` has a migration-specific rule because migrations are simultaneously the best
and most dangerous factory workload.

Best: they satisfy all four criteria for unattended operation almost by construction. Cheap
definitive checks (does it compile), fixed target so no drift, and work that decomposes into
short independent per-file loops.

Dangerous: the properties that make blast radius zero on an unlaunched project - no users,
no CI, thin tests - also make the verification surface zero. **A migration can compile,
typecheck, pass every existing test, and behave differently**, because the tests never
covered what changed. At high autonomy and high volume, that replicates everywhere before
anything surfaces it.

So gate 2 of a migration spec must answer one question before any other: **what is the
oracle?** And the first slices are not migration slices:

1. Make it build
2. Make it typecheck
3. Pin current behavior with characterization tests and golden-master snapshots
4. **Then** migrate, wide and fast, against the oracle you just built

This reads the back-pressure rule forwards rather than backwards. Instead of accepting the
verification budget you have and limiting autonomy to match, you go build a bigger budget
first and claim the autonomy it buys. Deterministic signals are not downstream checks on
finished work; they are upstream of how much work you are allowed to let run unattended.

---

## What is deliberately absent

**No auto-merge**, on any tier. Repository-side branch rules enforce it; harness hooks add
defense in depth.

**No ROI dashboard.** Nothing stock emits a complete cost record, so building one is a
project. Unique run records plus issue and PR timestamps still support queue age, gate
failure rate, verifier rejection rate, review time, and escaped-defect tracking.

**No steering or handoff layer.** You get `--teleport`, `/tasks`, `-p --cloud <id>`, and PR
comments. A vendor platform gives you more. That is a real gap, accepted knowingly.

**No self-improvement loop.** `/factory-tune` proposes; a human decides. A factory that
rewrites its own constraints has none.
