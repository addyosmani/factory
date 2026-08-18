# Quickstart

About 30 minutes. Do it on a `greenfield` repo first, not a client one.

## 0. Prerequisites

- Claude Code CLI installed and signed in with `claude auth login` (a claude.ai
  subscription login, **not** an API key: routines and `--teleport` both require it)
- Claude Code on the web enabled
- GitHub connected, one of:
  - the [Claude GitHub App](https://github.com/apps/claude) installed on the repo, or
  - `/web-setup` run in your terminal to sync your `gh` token

The App is required for **routine GitHub triggers** and for **auto-fix**. `/web-setup`
alone grants clone access but does not enable webhooks. If you want routine 3 (PR verify),
install the App.

Check:

```bash
claude --version && claude auth whoami
```

## 1. Install the template

```bash
cd /path/to/your/repo
/path/to/reference-software-factory/install.sh
```

It copies the shared factory contract, Claude Code files, the Codex adapter, and
`docs/factory/`, refusing to overwrite anything that already exists. Review the diff before
committing. The optional instant issue-trigger workflow is installed only with
`--with-issue-trigger`.

## 2. Write the charter

**This is the judgment step.** Gate wiring and repository enforcement also require review,
but the charter is where you decide which work the factory may attempt.

```bash
$EDITOR docs/factory/CHARTER.md
```

Set at minimum:

- **`CHARTER_STATUS`** - leave `incomplete` while editing; set it to `ready` only after
  reviewing every section.
- **`TIER`** - one of `revival`, `greenfield`, `oss`, `client-production`. This single
  choice sets how much autonomy every routine gets.
- **`LOAD_BEARING`** - globs no routine may touch unattended. Be generous at first; you can
  loosen later with evidence, and the reverse is more expensive.
- **`AUTOMATABLE`** - be specific. Vague entries produce vague triage.
- **`STOP_IF`** review-queue limit - start at 3.

Getting `AUTOMATABLE` wrong in the generous direction is the most common way this goes
badly. Start with dependency bumps and doc fixes. Add categories once you have evidence.

## 3. Wire the gates

```bash
$EDITOR .factory/gates.conf
$EDITOR .claude/scripts/gates.sh   # only when auto-detection needs project-specific logic
```

The script auto-detects node, python, rust, and go. Confirm it picks up your real commands:

```bash
./.claude/scripts/gates.sh fast
./.claude/scripts/gates.sh full
```

Required gates are listed by level in `.factory/gates.conf`. If one cannot run, the result
is `MISCONFIGURED` with exit 2. Optional gates may still show `SKIP`; decide deliberately
whether each belongs in the required list.

## 4. Bootstrap the live queue and enforcement

Preview, then create the GitHub labels used for claims and handoffs:

```bash
./.factory/scripts/bootstrap-github.sh
./.factory/scripts/bootstrap-github.sh --apply
```

Configure a GitHub ruleset or branch protection for the default branch and do not grant the
agent a bypass. The committed hooks catch common shell commands, but they are not a complete
enforcement boundary. The minimal settings are recorded in
`docs/factory/GITHUB.md`.

Run the setup check:

```bash
./.factory/scripts/doctor.sh
```

Then commit:

```bash
chmod +x .claude/scripts/gates.sh .claude/hooks/block-merge.sh .factory/scripts/*.sh
git add CLAUDE.md AGENTS.md .factory .claude .agents .codex docs/factory
git commit -m "factory: install"
git push
```

**Push before testing in the cloud.** Cloud sessions clone from the remote, not your local
checkout.

## 5. Test locally first

```bash
claude
```

```
/factory
```

You should get an empty control-room report. Then dry-run triage without letting it write:

```
Run the factory-triage skill, but only report what you would do. Write nothing and
apply no labels.
```

Read the output. If the dispositions look wrong, the charter is wrong. Fix it now, before
anything runs unattended.

## 6. Test in the cloud

```bash
claude --cloud "Run the factory-triage skill and report what you would do. Write nothing."
```

Monitor with `/tasks`, or open the session on claude.ai or the mobile app.

Two things to verify in this run specifically:

- the skill was found (it came from the repo clone, which is the whole factory-as-code bet)
- the built-in GitHub tools could read your issues without `gh`

If you need to take over, pull the session down:

```bash
claude --teleport
```

Requires a clean working tree and the same repo checkout.

## 7. Create the routines

Follow [ROUTINES.md](ROUTINES.md). **Create routine 1 (triage) only.** Let it run for a
few days before adding the rest.

Do not create all five on day one. You will not know which one is misbehaving, and the
daily run cap is easy to burn on a factory you have not yet learned to read.

## 8. Configure the cloud environment

At [claude.ai/code](https://claude.ai/code), open the environment selector.

The **Default** environment (Trusted network, no setup script) is enough for most repos. Add
a setup script only if your gates need tooling that is not pre-installed:

```bash
# runs once, then cached; keep under ~5 minutes
apt update && apt install -y gh
pnpm install --frozen-lockfile
```

Cloud sessions already include Node 20/21/22, Python with pytest/ruff/mypy, Ruby, PHP, Java,
Go, Rust, Docker, Postgres 16, and Redis.

**Record whatever you paste into that UI in a `CLOUD-ENVIRONMENT.md` in your repo.** It is
the one part of the factory that cannot be committed, so document it or it is lost on the
next machine.

## 9. First real run

Let triage run once. Then:

```bash
claude
```

```
/factory
```

Read the queue. For each item, ask whether you agree with the disposition. You are grading
the charter, not the agent: wrong dispositions mean the charter was ambiguous.

Only after triage produces dispositions you agree with should you add routine 2 (implement).

---

## Daily use

**Desktop, morning.** `/factory` in the repo you are working in. It leads with what needs
you and calls out the review queue depth.

**Fan out to cloud.** Independent tasks, each its own session:

```bash
claude --cloud "Implement FQ-142 following the factory-implement skill"
claude --cloud "Implement FQ-147 following the factory-implement skill"
```

Track with `/tasks`. Pull one back with `--teleport` when it needs you.

**Plan locally, execute remotely.** The highest-value pattern for anything non-trivial:

```bash
claude --permission-mode plan     # think it through, no edits
# save the plan into the repo, commit, push
claude --cloud "Execute the plan in docs/factory/specs/FQ-150/04-slices.md"
```

Judgment upstream, execution unattended. That split is the whole design.

**Steer a running session** from any machine without attaching:

```bash
claude -p "also update the changelog" --cloud <session-id>
```

**Watch a PR.** On its branch, `/autofix-pr` spawns a web session that responds to CI
failures and review comments. Requires the GitHub App. Do not enable it on repos where a PR
comment can trigger deployment automation.

**Monthly.** `/factory-tune`. Tighten where something escaped, loosen where you have a run
of evidence, and write the result to `DECISIONS.md`.

---

## When to stop expanding

Add the next routine when the current set has run clean for a week and you have read its
output. Stop adding when the review queue is regularly at its charter limit.

At that point more automation produces nothing. The constraint is not how many agents can
run, it is how many decisions are pending your judgment, and a full queue means the factory
should produce less rather than review faster.
