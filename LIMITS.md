# Limits, and where the common plan is wrong

Verified against Claude Code documentation, August 2026. Routines and Claude Code on the
web are both in **research preview**, so specifics move. Re-check before relying on any
constraint here.

---

## 1. There is no GitHub `issues` trigger

**The single most important constraint in this document.**

Routine GitHub triggers support two event categories only:

| Event | Actions |
|---|---|
| Pull request | opened, closed, assigned, labeled, synchronized, and other updates |
| Release | created, published, edited, deleted |

The canonical factory diagram starts with *new issue arrives → triage agent runs*. **You
cannot build that with a stock routine.** Every write-up that draws that arrow without
saying so has not tried it.

Three ways to close the gap:

| Option | Latency | Cost | Verdict |
|---|---|---|---|
| Scheduled routine polls untriaged issues | up to the interval, min 1 hour | zero extra files | **Default.** Fine for almost every repo |
| GitHub Action POSTs to the routine's API trigger | seconds | 1 YAML + 1 secret | Use when latency genuinely matters |
| Ask Claude to triage in a session | immediate | your attention | Not a factory |

The template ships option A by default and option B as
`template/.github/workflows/factory-fire.yml`.

---

## 2. Cloud environment config cannot be committed

This is the one real hole in factory-as-code, and it is worth knowing before you design
around it.

**Committed to the repo, so it works everywhere (terminal, Desktop, cloud, routines):**

- `CLAUDE.md`
- `.claude/settings.json`, including hooks
- `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`
- `.mcp.json` (project-scope MCP servers)
- plugins declared in `.claude/settings.json`

**Not committed. Account-level UI config you must set by hand:**

- cloud environment network access level and allowed domains
- environment variables
- the setup script
- routine definitions themselves: prompt, repos, triggers, connectors

So a repo can carry its entire factory *behavior* but not its *environment*. Record what you
pasted into the UI in `CLOUD-ENVIRONMENT.md` in your repo so it is at least version
controlled as documentation and reproducible on a new machine or by another person.

Two more gotchas in the same area:

- `~/.claude/skills/`, `~/.claude/agents/`, and your user `CLAUDE.md` do **not** reach cloud
  sessions. Anything the factory depends on must be in the repo.
- MCP servers added with `claude mcp add` at local or user scope do not reach cloud
  sessions either. Use `claude mcp add --scope project` so it writes `.mcp.json`, and commit
  it. Or add the server as a connector on claude.ai.

---

## 3. Environment variables are not secrets

The environment settings dialog says so directly: env vars and setup scripts are readable
by anyone who uses that environment. There is no secrets store yet.

For GitHub specifically you do not need one. Leave `GH_TOKEN` and `GITHUB_TOKEN` unset and
the GitHub proxy authenticates for you, keeping the real credential outside the VM. Both
variables then read as the literal string `proxy-injected`, which matters if you have a
script that reads `GITHUB_TOKEN` directly: it gets the placeholder, not a usable token.
`gh` itself works fine.

---

## 4. Green status does not mean the task worked

From the docs, and worth repeating because it is the most likely way to fool yourself:

> A green status in the run list means the session started and exited without an
> infrastructure error. It does not mean the task in your prompt succeeded.

Blocked network requests, missing connector tools, and outright task failure all show green.
This is why every execution writes a unique file under `docs/factory/runs/` and why
`factory-monitor` records what it checked and found clean. Evidence you can inspect beats a
status light you cannot.

---

## 5. Routines act as you, with every connector you leave attached

Commits and PRs carry your GitHub user. Slack messages and Linear tickets use your linked
accounts. Every connected connector is included by default when you create a routine, and a
running routine can call every tool from it, writes included, without asking.

Prune connectors per routine. The triage routine needs none.

---

## 6. Other limits worth knowing

| Limit | Value |
|---|---|
| Minimum routine schedule interval | 1 hour |
| Daily routine runs | Capped per account; one-off runs exempt |
| GitHub webhook events | Per-routine and per-account hourly caps during preview |
| Branch pushes | `claude/`-prefixed always accepted; others rejected if protected, if someone else has an open PR from them, or if they carry another author's commits |
| `gh` CLI | Not pre-installed; `apt install -y gh` in the setup script. Built-in GitHub tools cover issues, PRs, diffs, and comments without it |
| Setup script | Must finish in ~5 minutes; result is cached and rebuilt on change or after ~7 days |
| Cloud VM | Ubuntu 24.04 x86_64, fresh per session |
| Session handoff | `--teleport` pulls cloud → local. From the CLI, local → cloud is not a push; `--cloud` starts a *new* session. Desktop's **Continue in** menu can send a local session to the web |
| Default network | Trusted allowlist only. Reaching your own services needs Custom + explicit domains |
| IP allowlisting | If your org has it on, every Anthropic-hosted cloud session fails auth |
| Non-GitHub repos | GitLab and Bitbucket can be sent as a local bundle but cannot push results back |

---

## 7. Corrections to the widely circulated plan

The Grok-authored plan is directionally right. Specific errors:

| Claim | Reality |
|---|---|
| "Routines available on Max" | Pro, Max, Team, **and** Enterprise, all requiring Claude Code on the web enabled |
| "GitHub events (PR opened, **issue created**) for triage" | **No issue trigger exists.** Pull request and release only. This is the load-bearing error, because it is the entire first stage of the factory |
| "Use `claude --cloud` for sessions that continue after you disconnect" | Correct, but `--cloud` with a task **creates a new** cloud session. It does not push your current local session to the cloud. Only Desktop's **Continue in** menu does that |
| "Layer Agent SDK + Temporal/Prefect + E2B/Modal orchestration" | Unnecessary for a personal or single-team factory. Routines already provide schedule, API, and GitHub triggers on managed infrastructure. Reach for an SDK only when you need non-GitHub triggers or state that will not fit in repo files |
| "Model routing: cheap models for triage, strong for implementation" | Sound, but a routine's model is a single selector on the prompt, applied to every run. Per-stage routing means **separate routines per stage**, which the design here already does |
| "Docker sandboxes / K8s for isolation" | Cloud sessions already run in isolated per-session VMs with a credential proxy. Adding your own is duplicated work unless you have a compliance reason |
| "ROI tracking: log tokens, duration, outcome" | Nothing stock emits a complete record. Unique run files plus issue and PR timestamps provide useful quality and throughput measures; precise token-cost accounting remains additional infrastructure |

**The bigger disagreement is one of framing.** That plan optimizes for a large organization
standardizing many developers: governance, cost control, reducing human variability. That
framing is coherent *for that audience*.

For a portfolio of personal, open-source, and client repos, the constraint is different.
Human variability is not the problem, because there is one human. The problem is that one
human's review attention is the entire quality apparatus, with no org backstop behind it.
That points at a different design: fewer moving parts, everything in the repo, and hard
structural limits on how much work can be pending your judgment at once.

Which is why this reference has no orchestrator, queue service, or dashboard. It has a
shared contract, thin Claude/Codex adapters, five workflow skills, two review roles,
fail-closed gates, run records, and five Claude routines.

---

## 8. What this reference deliberately does not do

- **No auto-merge on any tier.** Enforced by repository branch rules; hooks add defense in depth.
- **No ROI or token dashboard.** Nothing stock emits the data; building it is a project.
- **No custom multi-harness orchestration layer.** Claude Code is primary. Codex receives
  project instructions, skill wrappers, and a hook adapter over the same repository
  contract. Claude cloud routine definitions are not translated automatically into Codex
  automations.
- **No custom orchestrator.** If you outgrow routines, the next step is the Claude Agent
  SDK, not Temporal.
- **No vendor platform.** By request. The tradeoff is that steering, handoff, and
  notifications are thinner here than a dedicated product provides: you get `--teleport`,
  `/tasks`, and PR comments rather than a control room.
