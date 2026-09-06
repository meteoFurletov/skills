<!-- sdlc-loop:begin -->
# Review policy

Owner: <name>. Every PR gets this pass before merge.

## Compliance

Check the diff against the `.feature` files, not against a green run.

Step definitions are the agent's to write, and a weak one makes a scenario pass
without the behaviour existing. No hook sees that. This is the one place the
scenario contract depends on a human reading the diff:

- For each scenario `plan.md` claims to prove, find the code that makes the
  `Then` true. If you cannot point at it, the scenario is not proven.
- Read any step definition that was added or changed. It must assert the
  observable result, not merely that the code ran.
- **Look for a `.feature` file deleted and recreated.** The hook that protects
  scenarios blocks modification, not deletion followed by a fresh write. A
  delete-and-add pair in the diff is legitimate only when it came from the spec
  transition; anywhere else it is the contract being rewritten quietly.
- A change declaring no scenarios still has to leave the existing ones passing.

## Correctness

- The diff does what `plan.md` said, and touches the files it listed. Where it
  departed, `plan.md` changed in the same commit.
- Errors are handled where they occur, not swallowed.
- No secrets, credentials or customer data.

## Fit

- New code reads like the code around it — same naming, idiom, comment density.
- Nothing landed that the spec put in non-goals.

## Deploy

Production releases wait for a named approver. Install that gate with
`/sdlc-loop:init --gate`.
<!-- sdlc-loop:end -->
