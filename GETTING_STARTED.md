# Get started from a desktop app

You can reach a safe local dry run without an API key, a custom orchestrator, or a cloud
routine. This guide installs the factory into one repository, opens that repository in
Claude Code Desktop or Codex in the ChatGPT desktop app, and uses the agent to help finish
the project-specific configuration.

Allow about 15 minutes for the first pass. Use a greenfield or disposable repository while
you learn the workflow. I would not make a client production repository the first test.

## What gets installed

This repository is a template and installer. You do not build your application inside the
`factory` repository. The installer copies a small set of committed files into the project
where you want the factory to run:

- `CLAUDE.md` and `AGENTS.md` give Claude Code and Codex project context.
- `.claude/` and `.agents/` contain the workflows each harness can discover.
- `docs/factory/CHARTER.md` records the work you will permit.
- `.claude/scripts/gates.sh` turns your existing checks into a deterministic verdict.
- GitHub labels become the live queue once you explicitly bootstrap them.

The installer refuses to overwrite existing files. Run it in dry-run mode first anyway;
safe defaults are useful, but they are not a substitute for reading the diff.

## 1. Clone and install

Clone this repository beside the project you want to configure:

```bash
git clone https://github.com/addyosmani/factory.git
git clone https://github.com/you/your-project.git
cd your-project
../factory/install.sh --dry-run .
../factory/install.sh .
```

If your project is already on disk, pass its absolute path instead:

```bash
/path/to/factory/install.sh --dry-run /path/to/your-project
/path/to/factory/install.sh /path/to/your-project
```

At this point nothing has been committed, pushed, scheduled, or connected to GitHub. The
new files are ordinary working-tree changes for you to review.

## 2. Choose a desktop path

Both desktop paths use the same charter, gates, queue, and evidence files. Claude Code is
the primary path and adds cloud sessions and routines. Codex provides an interactive path
through the same repository contract; this project does not pretend the two products have
identical schedulers.

### Claude Code Desktop

1. Open the **Code** tab in Claude Code Desktop.
2. Choose **Local** as the environment and select your target project folder, not the
   `factory` template folder.
3. Start in **Plan** mode, or use **Ask permissions** if Plan is unavailable.
4. Paste this prompt:

```text
Read CLAUDE.md, docs/factory/CONTRACT.md, docs/factory/CHARTER.md, and this
repository's build and CI files. Help me configure the factory for this project.

Begin by reporting only. Summarize the project, propose a tier, load-bearing paths,
automatable work, stop conditions, and the real commands for fast and full gates.
Ask me for decisions that require product or risk judgment.

Do not edit files, create GitHub labels, commit, push, create routines, or merge.
```

The useful output is a short configuration proposal grounded in files the agent actually
found. If it guesses at test commands or project risk, correct that before moving on.

Once you have approved the decisions, switch out of Plan mode and paste:

```text
Using the decisions I approved, update docs/factory/CHARTER.md, .factory/gates.conf,
and the project-specific commands and conventions near the top of CLAUDE.md.

Keep the factory contract and protected-path defaults intact. Run the fast and full
gates, then ./.factory/scripts/doctor.sh. Stop with the diff and quote the exact
FACTORY_GATES lines. Do not commit, push, create labels, create routines, or merge.
```

Review the visual diff file by file. The official Claude Code Desktop guide documents the
[project-folder, environment, permission, and diff-review controls](https://code.claude.com/docs/en/desktop).

### Codex in the ChatGPT desktop app

1. Open the target project folder as a Codex project.
2. Confirm that `AGENTS.md` appears in the project and read it before the first task.
3. Open `/hooks`, inspect the repository hook from `.codex/hooks.json`, and trust it only
   after the commands and protected paths match what you expect.
4. Start with a planning or read-only task and paste:

```text
Read AGENTS.md, CLAUDE.md, docs/factory/CONTRACT.md,
docs/factory/CHARTER.md, and this repository's build and CI files. Help me configure
the factory for this project.

Report first. Summarize the project, propose a tier, load-bearing paths, automatable
work, stop conditions, and the real commands for fast and full gates. Ask me for the
product and risk decisions you cannot infer safely.

Do not edit files, create GitHub labels, commit, push, or merge.
```

After approving the proposal, use the same configuration prompt from the Claude section.
Codex reads [`AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
discovers [repository skills](https://learn.chatgpt.com/docs/build-skills), and can load the
committed [repository hook](https://learn.chatgpt.com/docs/hooks). The installed adapters
point back to the canonical Claude workflows so the policy does not fork.

## 3. Check the result yourself

The agent should have run these, but run them once in the integrated terminal so you know
what healthy output looks like:

```bash
./.claude/scripts/gates.sh fast
./.claude/scripts/gates.sh full
./.factory/scripts/doctor.sh
```

The final gate line should be `status=GREEN`. `MISCONFIGURED` is a useful failure: it means
a required check could not run, rather than silently treating an absent test command as a
pass.

Now preview the GitHub labels. The first command writes nothing:

```bash
./.factory/scripts/bootstrap-github.sh
```

Only after the preview names the correct repository should you apply them:

```bash
./.factory/scripts/bootstrap-github.sh --apply
```

Configure branch protection or a GitHub ruleset before unattended work. The committed
hooks block common merge routes, but GitHub remains the enforcement boundary.

## 4. Commit the installation

Review the whole change before committing:

```bash
git status --short
git diff --check
git diff
git add CLAUDE.md AGENTS.md .factory .claude .agents .codex docs/factory
git commit -m "factory: install reference workflow"
git push
```

Cloud sessions always start from a remote clone, so they cannot see the factory until this
commit has been pushed.

## 5. Run the first control-room check

In Claude Code Desktop, type:

```text
/factory
```

In Codex, ask:

```text
Use the factory-status skill to show the control room. Report only; change nothing.
```

An empty queue is a valid result. Next, ask for a dry-run triage report:

```text
Run the factory-triage workflow in report-only mode. Do not write files or apply labels.
Explain every proposed disposition using the charter.
```

Read the proposed dispositions. A wrong disposition is usually a charter problem. Tighten
the charter before blaming or retraining the agent; the useful feedback loop starts with a
constraint you can inspect.

## Add cloud automation gradually

The desktop setup is enough for interactive use. When its local reports and gates are
predictable, continue with [QUICKSTART.md](QUICKSTART.md) for Claude cloud sessions,
GitHub-triggered verification, and routines.

Create the triage routine first and let it run for several days. Adding all five routines
on day one makes failures harder to attribute and can fill the review queue before you know
whether the charter is doing its job.
