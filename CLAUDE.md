# Factory reference development

This repository builds and documents a reference software factory. It is the distribution
repository, not an installed factory. Files under `template/` are copied into another
repository by `install.sh`.

## Read before changing behavior

- `README.md` is the public map and product boundary.
- `GETTING_STARTED.md` is the desktop-first tutorial.
- `ARCHITECTURE.md` explains the design decisions.
- `LIMITS.md` records product constraints that may change over time.
- `template/docs/factory/CONTRACT.md` is the harness-neutral installed policy.

Preserve the distinction between this repository's contributor instructions and the
`template/CLAUDE.md` instructions installed in user projects.

## Validation

Run the complete local suite before committing:

```bash
bash tests/run.sh
```

For a focused syntax check:

```bash
bash -n install.sh template/.claude/hooks/*.sh template/.claude/scripts/*.sh \
  template/.factory/scripts/*.sh tests/*.sh
jq empty template/.claude/settings.json template/.codex/hooks.json
```

The tests use disposable repositories. Do not point them at a real project.

## Change rules

- Keep `install.sh` idempotent and refuse to overwrite user files.
- Keep Claude Code as the canonical workflow definition. Codex adapters should remain thin
  and point to the same contract and workflow files.
- Treat the charter, required gates, merge boundary, and independent verification rule as
  protected behavior. A convenience change must not silently weaken them.
- Update the tutorial when a user-visible install step changes.
- Date product-specific claims in `LIMITS.md` and verify them against official
  documentation before changing them.
- Use small commits whose message names the behavior or documentation boundary changed.

## Writing

Write for a programmer trying this on a real repository. Prefer exact paths, commands,
expected output, and failure behavior over broad claims. State when Claude and Codex differ
instead of smoothing over the difference.
