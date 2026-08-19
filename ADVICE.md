# Pragmatic advice: start with the harness

**You can get surprisingly far with a coding harness, a clear work item, and repository-level
instructions. Start there. Add Factory when repeated, unattended work needs durable state,
consistent handoffs, bounded verification, and an explicit place for human judgment.**

Product-specific details below were checked in August 2026. Goals, schedules, and cloud
automation are moving quickly, so re-check the linked documentation before making them part
of a critical workflow.

## A software factory can start as a prompt

A useful software factory is a repeatable loop around software work. It takes an input such
as a GitHub issue, gathers context, makes a change, verifies the result, and hands the work
back at a boundary you chose. That first version does not require a queue service, an agent
SDK, or a custom control plane.

Claude Code already has an agentic loop that gathers context, acts, verifies, and repeats.
It also has [`/goal`](https://code.claude.com/docs/en/goal) for working toward a measurable
end state, [`/loop`](https://code.claude.com/docs/en/scheduled-tasks) for repeated prompts,
and [routines](https://code.claude.com/docs/en/routines) for cloud work started by a
schedule, API call, or supported GitHub event.

Codex has similar building blocks, although the product vocabulary is different. It can
[follow a goal](https://learn.chatgpt.com/use-cases/follow-goals) across turns and run
[scheduled tasks](https://learn.chatgpt.com/docs/automations) from ChatGPT on the web or
desktop. Codex does not currently document a direct equivalent to Claude Code's `/loop`
command. Use a goal when completion is the trigger, or a scheduled task when time is the
trigger.

Both harnesses can carry durable repository context. Claude Code reads `CLAUDE.md`; Codex
reads [`AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md). Skills
can package a workflow, while hooks and ordinary scripts can turn some written expectations
into mechanical checks. This is enough to automate a meaningful amount of work.

## The useful minimum

Start with one work item. A GitHub issue, a short spec, or a checked-in task list is fine.
Give the agent the information a capable engineer would need:

- the outcome and acceptance criteria;
- the files, packages, or services that are in scope;
- constraints, including paths it must not change;
- the commands that demonstrate correctness;
- the point where a human must review or decide;
- a stop condition for missing context, failing infrastructure, or unexpected risk.

Then put the rules that apply to every task in the repository. For a monorepo, keep common
budgets and checks at the root and add narrower instructions close to the package they
govern. Useful shared rules include supported runtimes, dependency policy, accessibility
requirements, test commands, performance budgets, security-sensitive paths, and the rule
that an agent opens a draft pull request rather than merging its own work.

Across several repositories, keep the common policy in one versioned template or skill and
install a pinned copy into each project. Leave project-specific exceptions beside the code
they govern, and periodically ask the harness to report which instructions it loaded. This
is less clever than a central policy service, but it is easy to inspect and works with a
normal clone.

A first prompt can be quite plain:

```text
Read GitHub issue #123 and the repository instructions before changing code.

Implement only the stated acceptance criteria. Do not modify authentication,
billing, migrations, or existing test assertions. Work in a branch and keep the
diff reviewable.

Run npm run lint, npm test, and npm run build. If a required check cannot run,
stop and explain why. Open a draft pull request with the checks you ran, the
remaining risks, and any decision a human still needs to make. Do not merge.
```

That is a small factory loop. A goal can keep it moving until the checks pass. A scheduled
task with GitHub access can poll for issues with a particular label or review open pull
requests each morning. Branch protection can enforce the merge boundary. The human stays in
the loop by choosing what becomes ready, reviewing the draft pull request, and making the
final merge decision.

Try this before adding orchestration. Watch where the process actually loses information or
requires repeated steering.

## When the harness is probably enough

I would stay with the stock harness when most of the following are true:

- one person or a small team can still understand the active queue;
- work is interactive, or a small number of scheduled jobs covers the unattended work;
- an issue or spec plus repository instructions reliably produces a reviewable change;
- CI and branch rules already enforce the important quality and merge boundaries;
- failures can return to the same person without a formal handoff protocol;
- there are few enough concurrent sessions that duplicate claims and conflicting branches
  are unusual;
- a pull request, its checks, and its comments are a sufficient audit trail.

This setup can handle feature batches, dependency updates, bug triage, pull request review,
documentation maintenance, and other work with clear inputs and observable outcomes. It is
also easier to tune because there are fewer abstractions between the prompt and the result.

## What Factory adds

Factory becomes useful when the prompt is no longer the hard part. The hard part is making
separate runs behave consistently, handing work between agents, preventing two sessions
from claiming the same issue, preserving evidence, and stopping production when human
review is falling behind.

This reference adds a shared protocol around the harness:

- GitHub labels own live queue state, with deterministic claims to prevent duplicate work;
- a charter records the human-owned risk boundary and paths that need extra care;
- Claude Code and Codex use the same contract rather than drifting into separate policies;
- gate scripts emit a deterministic verdict and fail closed when a required check is missing;
- implementation and independent verification are separate roles;
- run records preserve what happened after the chat transcript is gone;
- back-pressure stops new work when the review queue exceeds its human-owned limit;
- every successful run ends at a draft pull request. A human still merges.

These controls are useful for unattended work, multiple repositories, multiple harnesses,
or a queue large enough that its state no longer fits in one person's head. Factory's main
return is consistency, evidence, and safer handoffs. An individual feature may finish more
slowly because it now passes through more boundaries.

## Budget the verification, too

Verification is where a responsible factory spends much of its time. This is desirable up
to the point where repeated checks add delay without adding useful evidence.

Suppose a full suite takes eight minutes. Ten separately claimed features consume at least
80 minutes of full-suite time if each passes once. If an independent verifier runs the same
suite again, the lower bound becomes 160 minutes before retries, environment setup, browser
checks, or human review. The implementation can be quick while the batch still feels slow.

Treat verification as a budget:

- run fast checks such as types, lint, and focused tests while shaping the change;
- run the full suite at the pull request boundary and after the final material fix;
- reserve deep security, mutation, architecture, or broad end-to-end checks for risk that
  warrants them, or run them on a separate cadence;
- group closely related changes when they have one acceptance boundary and remain easy to
  review. Atomic should describe a coherent unit, not the smallest possible diff;
- cap failed verification attempts and ask a human to resolve ambiguity instead of looping
  indefinitely;
- measure elapsed time, reruns, false rejections, escaped defects, and human review time.
  Adjust a gate when the evidence says it is too weak or too expensive.

The defaults in this repository lean conservative because unattended changes should earn
trust. They are still defaults. A two-minute documentation fix and an authentication
migration should not pay the same verification cost.

## A practical progression

For most repositories, I would adopt these ideas incrementally:

1. Start with a well-written issue or spec and one explicit implementation prompt.
2. Move repeated constraints into `CLAUDE.md`, `AGENTS.md`, and deterministic project
   scripts.
3. Add a goal for bounded long-running work. Add a schedule only after the prompt succeeds
   interactively.
4. Let the agent open draft pull requests, while CI, branch rules, and a human own shipping.
5. Install Factory when queue state, handoffs, independent verification, or back-pressure
   solve a problem you have actually observed.
6. Consider a custom orchestrator only when stock schedules, goals, GitHub, and repository
   state cannot express a requirement you genuinely need.

The [Reel Good demo](https://github.com/addyosmani/factory-demo) and its
[step-by-step workshop](https://github.com/addyosmani/factory-demo/blob/main/docs/WORKSHOP.md)
show the fuller path. You can use the early checkpoint to try the harness-only approach,
then compare it with the installed Factory workflow.

## Product documentation

- Claude Code: [how the agentic loop works](https://code.claude.com/docs/en/how-claude-code-works),
  [goals](https://code.claude.com/docs/en/goal),
  [loops and scheduled tasks](https://code.claude.com/docs/en/scheduled-tasks), and
  [cloud routines](https://code.claude.com/docs/en/routines).
- Codex: [goals](https://learn.chatgpt.com/use-cases/follow-goals),
  [scheduled tasks](https://learn.chatgpt.com/docs/automations),
  [`AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
  [skills](https://learn.chatgpt.com/docs/build-skills), and
  [hooks](https://learn.chatgpt.com/docs/hooks).
