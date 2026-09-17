# Review policy

Applied by Copilot code review on every pull request, and by `/sdlc-loop:deploy`
when it addresses the findings. Owner: <name>.

The agent that wrote the code does not approve it. Review the diff; do not run
tests or report that they pass — the Test stage already did that.

## Compliance

- The diff does what `plan.md` in the active change directory says, and touches
  the files it lists. A departure is recorded under Departures in the same
  change; an unrecorded one is a finding.
- A `.feature` file modified, deleted or recreated outside a design commit — one
  that also changes that change's `spec.md` — is the contract being rewritten
  quietly. Flag it.
- A step definition changed after the design commit must still assert the
  observable result. A weakened assertion is a finding of the highest severity.
- Nothing landed that `spec.md` lists under Non-goals.

## Correctness

- Errors are handled where they occur, not swallowed.
- No secrets, credentials or customer data.
- Names match the repo's estate document where one exists.

## Fit

- New code reads like the code around it: same naming, idiom, comment density.

Rank findings by severity. Say clearly when there are none.
