---
description: Stage 5 — run this repo's REVIEW.md pass over the current diff, checking it against the .feature files rather than a green run.
argument-hint: [optional — a PR number, branch or path to review]
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(jq:*), Bash(gh pr view:*), Bash(gh pr diff:*)
disallowed-tools: Edit Write MultiEdit NotebookEdit
---

Run the review pass over: $ARGUMENTS

If that is empty, review the current diff against the base branch.

Read `REVIEW.md` in this repo and follow it. If there is none, say so and offer
`/sdlc-loop:init` — do not invent a policy.

## The compliance pass

This is the part no hook can do. Check the diff against the `.feature` files,
not against a green run:

- For each scenario `plan.md` claims to prove, point at the code that makes the
  `Then` true. If you cannot point at it, the scenario is not proven — say so
  plainly rather than treating a passing run as cover.
- Read any step definition that was added or changed. A weak one makes a scenario
  pass without the behaviour existing, and nothing mechanical catches that.
- **Look for a `.feature` file deleted and recreated.** `protect-scenarios`
  blocks modification, not delete-then-write. A delete+add pair is legitimate
  from the spec transition and nowhere else; anywhere else it is the contract
  being rewritten quietly, and it is a finding.
- A change that declared no scenarios still has to leave the existing ones
  passing.

## Then the rest of REVIEW.md

That the diff does what `plan.md` said and touched the files it listed; that
departures moved `plan.md` in the same commit; that nothing landed which the spec
put in non-goals; that new code reads like the code around it.

Report findings most-serious first, each with file and line and what specifically
is wrong. Say clearly when you found nothing. Fix nothing in this run.
