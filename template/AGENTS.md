# Project and factory guidance for Codex

Read `CLAUDE.md` for the project's commands and conventions, then read
`docs/factory/CONTRACT.md` and `docs/factory/CHARTER.md` before changing anything.
For first-time setup and the local dry run, follow `docs/factory/README.md`.

The contract is shared with Claude Code. If this adapter and the contract disagree, the
contract wins. Use the repo-scoped skills under `.agents/skills/` for factory workflows.

Repository hooks in `.codex/hooks.json` are defense in depth. They require local trust and
do not replace GitHub branch protection.
