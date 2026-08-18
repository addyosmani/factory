# Contributing

Factory is small enough to understand from the repository. A useful change should keep it
that way.

## Find the right layer

- Change `template/docs/factory/CONTRACT.md` when both Claude Code and Codex need the same
  policy.
- Change a canonical workflow under `template/.claude/skills/` when the sequence of work
  changes.
- Keep `template/.agents/skills/` as thin Codex adapters. Duplicating a workflow there
  creates two implementations that can drift.
- Change `install.sh` when distribution behavior changes. It must remain safe to rerun and
  must never overwrite an existing file.
- Put product limitations in `LIMITS.md`, not in optimistic setup prose.

## Validate a change

Run:

```bash
bash tests/run.sh
```

The suite installs the template into disposable Git repositories and exercises gate
failures, concurrent claims, merge guards, the setup doctor, and negative-test restoration.
When changing one of those boundaries, add the failing test first.

For an onboarding change, also follow [GETTING_STARTED.md](GETTING_STARTED.md) from a clean
target repository. The first experience should not require the reader to understand cloud
routines, hooks, or the queue protocol before seeing a local dry run.

## Keep the history readable

Use one commit per behavior or documentation boundary. A few examples:

```text
feat: detect pnpm gates
fix: preserve monitor labels during triage
docs: clarify Codex hook trust
test: cover concurrent issue claims
```

Avoid mixing a policy change, a workflow change, and a prose cleanup in one commit. The
factory asks agents to leave durable evidence; its own history should meet the same bar.

## Before opening a pull request

- Confirm `bash tests/run.sh` passes.
- Read the diff without whitespace hiding enabled.
- Explain any changed safety boundary in the pull request body.
- Link the official Claude Code or OpenAI documentation for product-behavior claims.
- Do not include credentials, routine API tokens, client repository data, or generated run
  records from a private project.
