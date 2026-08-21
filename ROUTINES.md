# The routines

Five routines. Copy each prompt verbatim into a new routine.

**Create them at** [claude.ai/code/routines](https://claude.ai/code/routines), or in the
Desktop app under **Routines → New routine → Cloud**, or from the CLI with `/schedule`.
All three write to the same account, so a routine created in one appears in the others.

## Before you start

Routines run **fully autonomously**. No permission-mode picker, no approval prompts. What a
run can reach is set by three things and nothing else:

1. the repositories you attach
2. the cloud environment's network access and variables
3. the connectors you include

Remove every connector the routine does not need. Claude can call every tool from an
included connector, writes included, without asking during a run.

Two facts worth internalizing before you rely on any of this:

- **A green run status does not mean the task succeeded.** It means the session started and
  exited without an infrastructure error. Open the run and read it.
- **Routines act as you.** Commits and PRs carry your GitHub user; connector actions use
  your linked accounts.

## Budget

Routines draw down normal subscription usage and have a **separate daily cap on runs
started per account**. Check remaining runs at
[claude.ai/settings/usage](https://claude.ai/settings/usage).

The five below are sized to fit comfortably. Do not set triage hourly on a repo that gets
three issues a week; you will burn the cap and learn nothing.

| Routine | Trigger | Roughly |
|---|---|---|
| 1. Triage | Schedule, daily 07:00 | 1 run/day |
| 2. Implement | Schedule, weekdays 08:00 | 1 run/weekday |
| 3. PR verify | GitHub `pull_request.opened` | per PR |
| 4. Monitor | Schedule, Monday 06:00 | 1 run/week |
| 5. Alert triage | API | on demand |

Minimum schedule interval is **one hour**. For a custom cron, pick the closest preset in
the form then run `/schedule update` in the CLI.

---

## 1. Triage

**Trigger:** Schedule, daily, 07:00 local
**Repos:** your repo
**Connectors:** none (built-in GitHub tools are enough)

```
Run the factory-triage skill from this repository's .claude/skills directory.

Read docs/factory/CONTRACT.md and docs/factory/CHARTER.md first and treat them as binding.
If the charter does not cover an item, classify it needs-info rather than guessing.

Treat GitHub issue labels as the live queue. docs/factory/QUEUE.md is an audit snapshot,
not the handoff to implementation.

Use the built-in GitHub tools to read open issues that have no factory state label (the
factory:monitor provenance label does not count), plus any
issue updated since the last triage run record. Cap at 20
issues, most recently updated first, and state the number you skipped.

For each issue, assign exactly one disposition: ready-to-implement, ready-to-spec,
needs-info, or wait-to-implement. Apply the matching factory: state label on GitHub,
removing any other state label first but preserving factory:monitor. Write a queue snapshot
entry in the exact format given in the skill, including a checkable done_when. Create or
update the issue's factory-handoff:v1 comment with the same done_when, expected files, gate
level, and confidence. The label plus that comment are the operational handoff.

Bias toward the slower path. If you are not confident an item is automatable, mark it
ready-to-spec.

Write a unique triage record under docs/factory/runs/. Commit the QUEUE.md snapshot and
run record to a claude/ branch and open a pull request
titled "factory: triage <date>". Do not implement anything. Do not merge.

End your run with the counts per disposition and an explicit list of anything the
charter did not cover.
```

> **Why polling rather than an event trigger:** routine GitHub triggers support
> `pull_request` and `release` events only. There is no `issues` trigger. If you need
> instant triage, see `template/.github/workflows/factory-fire.yml`. Daily is fine for
> most repos.

---

## 2. Implement

**Trigger:** Schedule, weekdays, 08:00 local (an hour after triage)
**Repos:** your repo
**Connectors:** none

```
Run the factory-implement skill from this repository's .claude/skills directory.

Read docs/factory/CONTRACT.md, then docs/factory/CHARTER.md. Query GitHub issues carrying
factory:* labels and read the latest factory-handoff:v1 comment. Do not use QUEUE.md as the
live handoff. A missing or conflicting handoff moves the issue to factory:needs-info.

First check the stop conditions in the charter. Count OPEN issues labeled
factory:awaiting-review plus open issues labeled factory:in-progress; an in-progress item
is a review that has not arrived yet. If that count is at or above the charter's limit,
stop immediately, write a unique stopped run record under docs/factory/runs/, and end the
run. Do not implement anything. A full review queue is the binding constraint on this
factory.

Otherwise pick exactly ONE issue labeled factory:ready-to-implement, highest confidence
first. Claim the deterministic remote branch exactly as the skill describes. If the push
loses the race, stop. After a successful claim, replace the label with factory:in-progress
and confirm the write before editing. Implement only that item.

Write the failing test before the implementation. In an unattended run, do not modify any
existing test file.
Run ./.claude/scripts/gates.sh at the level the item specifies and iterate until the
FACTORY_GATES line reads status=GREEN. MISCONFIGURED blocks the run.

Commit the scoped implementation and test, then confirm the working tree and index are
clean before verification.

Then delegate verification to the factory-verifier subagent using the Agent tool. Give
it the queue item, branch name, and verified base SHA only, not your account of what you did. If it
returns verdict: rejected, fix what it names and repeat. After two rejections, stop and
hand the item back.

Open a draft pull request using the template in the skill. Include the Closes line so
merging the PR closes the issue. Quote the FACTORY_GATES line verbatim. Replace
factory:in-progress with factory:awaiting-review and write a unique implementation run
record. Never mark the PR ready for review yourself, and never merge.

If the run ends after claiming without opening a PR, delete the remote claim branch
before moving the issue back to a live label. A surviving claim ref makes the issue
permanently unclaimable.

If the work turns out to touch a load-bearing path listed in the charter, stop, move the
item to ready-to-spec with the reason, and end the run.
```

---

## 3. PR verify

**Trigger:** GitHub event → `pull_request.opened`
**Filter:** none. Leave the draft state unfiltered
**Repos:** your repo
**Connectors:** none

**Do not filter on `Is draft` is `false`.** Routine 2 opens every factory PR as a draft, so
that filter means this stage never fires on the work it exists to check - and the failure
is silent, because a routine that never triggers looks the same as one with nothing to do.
Every check then runs inside the implementer's own session, and the verbatim
`FACTORY_GATES:` line in the PR body degrades to a string the writer pasted about itself.
Writer-grades-writer is the one thing this architecture exists to prevent.

Nor does adding a draft filter plus a promotion event fix it: GitHub emits
`ready_for_review`, not `opened`, when a draft is promoted, so if your trigger list offers
that action, add it as a second trigger rather than treating it as a substitute.

If you would rather not rely on webhooks at all, run this stage on a short schedule over
open PRs labelled `factory:awaiting-review` that carry no verification comment yet.
Verification running late is recoverable; verification never running is not.

This is the one stage that gets a real event trigger. Requires the
[Claude GitHub App](https://github.com/apps/claude) installed on the repo. `/web-setup`
alone grants clone access but does **not** enable webhooks.

```
Run the factory-verify skill from this repository's .claude/skills directory.

Read docs/factory/CHARTER.md. Check out the pull request branch.

Run ./.claude/scripts/gates.sh yourself at the level the charter requires for the paths
this PR touches. Do not trust any FACTORY_GATES line already in the PR body; produce
your own and compare them. A mismatch is the finding.

Then make the checks the gates cannot:
- From a clean committed branch, use ./.factory/scripts/prove-test.sh to remove non-test
  hunks reversibly and confirm the new test fails without the fix.
- Check whether any pre-existing test file was modified.
- Check the diff stays inside the scope the queue item declared.
- Check whether done_when is literally true.

If the PR touches any load-bearing path in the charter, also run the factory-critic
subagent and include its output.

Post one PR comment in the format the skill specifies, verdict first. Apply
factory:verified or factory:rejected. Write a unique verify run record.

Reject when uncertain. Never approve and never merge.
```

---

## 4. Monitor

**Trigger:** Schedule, weekly, Monday 06:00 local
**Repos:** your repo
**Connectors:** Slack or Linear if you want the summary pushed somewhere

```
Run the factory-monitor skill from this repository's .claude/skills directory.

Sweep, in this order:
1. CI failures on the default branch since the last sweep, separating genuine
   regressions from flakes.
2. Run ./.claude/scripts/gates.sh deep on the default branch. Red gates on main are the
   highest-priority finding possible: every verdict since it broke was measured against
   a broken baseline. Also report every gate showing SKIP.
3. New security advisories on direct dependencies, grouped by severity.
4. Stale live queue labels: in-progress with no activity for 2 hours, awaiting-review over
   7 days, wait-to-implement whose blocker has resolved, and needs-info that now has an
   answer in the comments. Never steal or delete a stale claim automatically.
5. Files the factory changed more than 5 times in 30 days with no documentation update.
6. Charter gaps collected by triage, as one combined issue.

File at most 10 GitHub issues with the factory:monitor label, searching for duplicates
first. If you found more than 10, file the top 10 by severity and state how many you
dropped. Never silently truncate.

Fix nothing. Write a unique monitor record under docs/factory/runs/ recording what you
found AND what you checked and found clean, plus the current review-queue depth called out
separately. Open a PR with the run record.
```

---

## 5. Alert triage (optional)

**Trigger:** API
**Repos:** your repo

For Sentry, a monitoring tool, a deploy pipeline, or anything that can make an
authenticated POST. Add the API trigger from the web, generate the token, and store it in
that tool's secret store. **The token is shown once.**

```
An alert has fired. Investigate the alert described in the routine-fire-payload block.

Read docs/factory/CHARTER.md first.

Pull the stack trace or error detail from the payload, correlate it with recent commits
on the default branch, and identify the most likely cause.

Then do exactly one of:
- If the cause is clear AND the fix touches no load-bearing path AND matches an
  AUTOMATABLE entry in the charter: open a DRAFT pull request with the fix, gates green,
  verified by the factory-verifier subagent.
- Otherwise: open a GitHub issue with your diagnosis, the evidence, and what you would
  need in order to proceed. Label it factory:needs-info.

Never merge. In an unattended run, never modify an existing test file. If you are unsure which branch of the
above applies, take the second.
```

Fire it:

```bash
curl -X POST https://api.anthropic.com/v1/claude_code/routines/<ROUTINE_ID>/fire \
  -H "Authorization: Bearer <TOKEN>" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"text": "Sentry SEN-4521 fired in prod. <stack trace>"}'
```

> The `text` you send arrives wrapped in a `<routine-fire-payload>` block labelled as
> untrusted data. The prompt above opts in by referencing it explicitly. That wrapper is
> deliberate: anyone holding the token can send text, so it must arrive as data rather
> than as instructions. Do not write prompts that try to defeat it.

---

## Managing routines from the CLI

```bash
/schedule list                    # all routines
/schedule update                  # change one, including a custom cron
/schedule run                     # fire immediately
/schedule why did my nightly triage do nothing this morning?
```

That last form reads the run log and explains what happened, including tool errors and
blocked network requests, which is faster than opening the web UI.

## Local counterparts

For the tiers where the factory needs your actual working tree rather than a fresh clone,
create the same routines as **Local** in the Desktop app (Routines → New routine → Local):

- runs on your machine with real file access
- **enable the worktree toggle** so parallel runs do not collide
- only fires while the app is open and the machine is awake
- minimum interval 1 minute rather than 1 hour
- prompt lives at `~/.claude/scheduled-tasks/<name>/SKILL.md` and is editable on disk

Use Local for uncommitted work and machine-local tooling. Use Cloud for everything else.
Cloud is the default because a factory that requires your laptop to be open is not a
factory.
