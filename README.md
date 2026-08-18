# Reference software factory

A working software factory built from **stock Claude Code and a subscription that includes
Claude Code on the web**. No orchestrator, no queue service, no vendor platform. A thin
Codex adapter uses the same contract, queue, gates, and evidence files.

The Claude path runs on committed skills and subagents, cloud routines, cloud sessions, one
gate script, and defense-in-depth hooks. Codex reads `AGENTS.md`, repo-scoped skills, and a
repo hook without introducing a second factory definition.

```
reference-software-factory/
├── README.md            <- you are here
├── QUICKSTART.md        30 minutes, first repo
├── ARCHITECTURE.md      why it is shaped this way
├── ROUTINES.md          the five routine prompts, copy verbatim
├── LIMITS.md            honest constraints + corrections to the common plan
├── install.sh
├── tests/               disposable-repo smoke tests
└── template/            shared contract plus Claude Code and Codex adapters
```

## Install

```bash
cd /path/to/your/repo
/path/to/reference-software-factory/install.sh
```

Then read [QUICKSTART.md](QUICKSTART.md). It never overwrites an existing file, so re-running
is safe.

---

## What you get

| Piece | File | Does |
|---|---|---|
| **Charter** | `docs/factory/CHARTER.md` | Human-owned tier, load-bearing paths, automatable work, definition of done, and stop conditions |
| **Contract** | `docs/factory/CONTRACT.md` | Harness-neutral queue protocol, policy, and durable-evidence rules |
| **Gates** | `.claude/scripts/gates.sh` | Types, lint, tests, build, audit, mutation, architecture. Three levels. Emits a verdict line no agent may paraphrase. |
| **Live queue** | GitHub `factory:*` labels | Visible state and handoff between independent runs |
| **Concurrency claim** | deterministic `claude/fq-<n>` branch | First non-forced push wins; later runs stop |
| **Triage** | `.claude/skills/factory-triage/` | Issues → live labels plus a reviewable queue snapshot |
| **Spec** | `.claude/skills/factory-spec/` | Four human-approved gates before any code exists |
| **Implement** | `.claude/skills/factory-implement/` | One item, test first, gates green, independently verified, draft PR |
| **Verifier** | `.claude/agents/factory-verifier.md` | Reads the diff cold. Reverts the fix to prove the test fails. Rejects when uncertain. |
| **Critic** | `.claude/agents/factory-critic.md` | Adversarial second lens on load-bearing changes |
| **Verify** | `.claude/skills/factory-verify/` | PR-level check, driven by a GitHub-triggered routine |
| **Monitor** | `.claude/skills/factory-monitor/` | Weekly sweep that closes the loop by filing issues |
| **Control room** | `/factory` | What needs you, right now, review queue first |
| **Tuning** | `/factory-tune` | Monthly constraint review, proposes only |
| **Merge guard** | `.claude/hooks/block-merge.sh` | Blocks common shell merge paths; GitHub rules remain the enforcement boundary |
| **Doctor** | `.factory/scripts/doctor.sh` | Finds placeholders, missing labels, missing remotes, and setup gaps |

## The pipeline

```
issue ──▶ TRIAGE ──▶ ready label ──▶ claim branch ──▶ IMPLEMENT ──▶ VERIFIER ──▶ draft PR ──▶ ┐
 (cloud, scheduled)    │                     (cloud)      (subagent)                │
                       ├─▶ ready-to-spec ──▶ SPEC ──▶ slices ───────────────────────┤
                       │                    (desktop, 4 human gates)                │
                       ├─▶ needs-info ─────▶ parked, question on the issue          │
                       └─▶ wait-to-impl ───▶ parked, blocker named                  │
                                                                                    ▼
       MONITOR ◀── ship ◀── HUMAN MERGES ◀── /factory ◀── VERIFY ◀────────────── PR opened
   (weekly, files issues)   (never automated)  (control room)  (cloud, on PR event)
```

Two stages are deliberately not automatable. **Spec** is where product intent and system
shape get decided, and no oracle grades those. **Ship** is where accountability lives.

## Desktop and cloud

Both, from the same committed files. Cloud sessions clone the repo, so whatever is in
`.claude/` works identically everywhere.

| | Desktop / CLI | Cloud |
|---|---|---|
| Control room | `/factory` | - |
| Spec gates | **here**, interactive | no |
| Fan out | `claude --cloud "..."` × N | each its own session |
| Track | `/tasks` | claude.ai/code, mobile app |
| Take over | `claude --teleport` | - |
| Steer without attaching | `claude -p "..." --cloud <id>` | - |
| Unattended | Local routines (needs machine awake) | **Cloud routines** |
| Watch a PR | `/autofix-pr` | web session |

The highest-value pattern, and the one that makes the whole thing work:

```bash
claude --permission-mode plan     # think it through locally, no edits
# save the plan into the repo, commit, push
claude --cloud "Execute the plan in docs/factory/specs/FQ-150/04-slices.md"
```

Judgment upstream, execution unattended.

---

## The four ideas doing the work

**1. Everything lives in the repo.** Cloud sessions start from a fresh clone. Committed
`.claude/` reaches them; your `~/.claude/` does not. So one set of files drives terminal,
Desktop, cloud, and routines with no config to keep in sync.

**2. Autonomy tracks consequence, not difficulty.** The charter's `TIER` sets how much
freedom every routine gets. A ten-thousand-line migration on an unlaunched project is a
safer bet than a fifty-line change to a client's auth path, and the config should say so.

**3. The gate script is the verdict.** `gates.sh` ends with a line skills must quote
verbatim. A missing required gate is `MISCONFIGURED` with exit 2, so an absent test command
cannot quietly become a green run.

**4. The writer never grades the work.** Implementation delegates to a separate verifier
that reads the diff cold and is told to ignore any account of what was done. Its best check
is one no gate can make: revert the fix and confirm the test actually fails.

## The two constraints most people delete

**Back-pressure is a number.** `STOP_IF` in the charter caps how many items may sit awaiting
review. When the queue is full, the implement routine refuses to start. The binding
constraint on a factory is not how many agents can run, it is how many decisions are pending
your judgment.

**Merge is never automated**, on any tier. Enforce this with a GitHub ruleset or branch
protection. The committed Claude and Codex hooks catch common shell routes, but hooks are a
guardrail rather than a complete security boundary.

---

## Before you build on this

Read [LIMITS.md](LIMITS.md). The headline:

- **There is no GitHub `issues` trigger.** Routine GitHub triggers cover `pull_request` and
  `release` only. The canonical *new issue → triage* arrow cannot be built with a stock
  routine. The template polls on a schedule by default and ships an optional Action that
  fires the routine's API endpoint if you need it instant.
- **Cloud environment config cannot be committed.** Network, env vars, and setup scripts are
  account-level UI state. Document yours in a `CLOUD-ENVIRONMENT.md`.
- **A green run status does not mean the task succeeded.** It means the session exited
  without an infrastructure error.
- **Environment variables are not secrets.** Leave `GH_TOKEN` unset; the GitHub proxy
  handles auth and keeps the credential out of the VM.

## Codex compatibility

Codex reads [`AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
discovers [repo-scoped skills](https://learn.chatgpt.com/docs/build-skills) under
`.agents/skills/`, and can load the defense-in-depth
[hook](https://learn.chatgpt.com/docs/hooks) from `.codex/hooks.json`. The wrappers point
back to the same Claude-first workflows and shared contract, so policy and state do not
fork by harness.

Codex users review and trust the repository hook with `/hooks`. The contract, gate script,
issue labels, and run records still work when the hook is disabled.

The saved cloud routines in `ROUTINES.md` remain Claude-specific. Codex can run the same
skills interactively or through its own automation surfaces, but this reference does not
pretend the two schedulers have identical triggers or lifecycle semantics.

LIMITS.md §7 also corrects the widely circulated build plan point by point. The load-bearing
error in that plan is the issue trigger, because it is the first stage of the pipeline.

## Validate the reference

The local suite creates disposable Git repositories and exercises installation,
idempotency, fail-closed gates, deterministic claim races, merge guards, setup diagnosis,
and negative-test restoration:

```bash
bash tests/run.sh
```

## Further reading

Start with Dex Horthy's software-factory playbook,
["Harness Engineering Is Not Enough: Why Software Factories Fail"](https://youtu.be/htM02KMNZnk?t=27219).
It makes the most important constraint concrete: generation scales more easily than human
judgment, verification, and long-term comprehension.

- [Zach Lloyd's guide to cloud software factories for engineering leaders](https://www.warp.dev/blog/a-guide-to-cloud-software-factories-for-engineering-leaders)
  describes the larger organizational model and the full
  `triage → spec → implement → review → verify → ship → monitor` loop.
- Warp's practical build series starts with
  [automatic triage](https://www.warp.dev/blog/how-to-build-a-cloud-software-factory-the-automatic-triage-skill)
  and continues with
  [spec-driven development](https://www.warp.dev/blog/how-to-build-a-cloud-software-factory-add-spec-driven-development-skills).
- The official Claude Code documentation explains the extension primitives used here:
  [project instructions, skills, subagents, hooks, and plugins](https://code.claude.com/docs/en/features-overview).
- The official OpenAI documentation covers Codex
  [project instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
  [repository skills](https://learn.chatgpt.com/docs/build-skills), and
  [hooks](https://learn.chatgpt.com/docs/hooks).

This reference is intentionally smaller than the organization-scale designs above. In a
personal portfolio, developer variability is not the binding constraint. One person's review
attention is the entire quality apparatus, which argues for fewer moving parts, state owned
by the repository, and a hard cap on pending decisions.
