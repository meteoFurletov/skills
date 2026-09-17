---
description: Stage 4, Test — run the verify commands once more in a fresh context, then a verifier that did not write the code checks spec, scenarios, bindings and code against each other. Produces a fix or a stop, never a file.
argument-hint: [optional — the change directory to test]
allowed-tools: Read, Glob, Grep, Bash, Agent, Skill
---

Test the change: $ARGUMENTS

If that is empty, use `<artifactDir>/CURRENT`.

## Before anything

Read `.claude/sdlc.json` at the git root. If it is absent, say that this repo has
not run `/sdlc-loop:init` and that the hooks are inert here, then continue with
the defaults `artifactDir: docs/sdlc`, `scenarioGlobs: ["features/**/*.feature"]`
and no facts document.

Artefacts live one directory per change: `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` naming the active one. Take the date from `date +%F`,
never from your own sense of today.

Read the facts document named by `facts` before drafting a word. It holds the
estate's real names and the facts the code does not say; a draft that spells a
system, repo or table differently from that file is wrong before the owner reads
it. If a name you need is missing there, ask, and add it there first.

## Loading a template

Read `${CLAUDE_PLUGIN_ROOT}/templates/<name>`. If that path does not exist, fall
back to the install path from
`jq -r '(.plugins // .) | to_entries[]|select(.key|startswith("sdlc-loop@"))|.value[0].installPath' ~/.claude/plugins/installed_plugins.json`
plus `/templates/<name>`. If both fail, say so and stop. Never write a template
from memory — re-deriving it by hand is the drift this plugin exists to stop.

## First, the feedback loop's last word

Run every command in the `verify` block. Red here goes straight back to Build:
say what failed and follow `${CLAUDE_PLUGIN_ROOT}/commands/build.md` until it is
green, then come back here. Green here is necessary, not sufficient.

## Then the verifier

Spawn one subagent with a fresh context — one that did not write the code — and
give it the paths of `spec.md`, the `.feature` files the plan proves, their
bindings, the git ref of the design commit (the last commit that changed this
change's `spec.md`), and the diff since. It reads, runs nothing, and reports
findings ranked by severity, or says clearly that it found none. Its checks:

1. **Spec against scenarios.** Every requirement has a scenario that exercises
   it, or the spec says in one line why it needs none. No two scenarios
   contradict each other.
2. **Scenarios against bindings.** Each `Then` step asserts the observable
   result the scenario states, not that code ran. Diff the bindings against the
   design commit: an assertion that was weakened, removed or made vacuous since
   then is the highest-severity finding there is.
3. **Code against spec.** For each requirement, the code that satisfies it,
   named. Logic a requirement demands and the code lacks is a finding. Anything
   under Non-goals that landed is a finding.
4. **Plan against reality.** Files touched but absent from the plan's list and
   its Departures.

## What happens with findings

Nothing is written for a person to read: a finding is either fixed or it stops
the loop.

- A finding in the code or in binding glue goes back to Build: fix it, run the
  verify commands green, and run the verifier again. Two rounds is normal; a
  third with the same finding means the plan is wrong — stop and say so.
- A finding against a scenario, an assertion or the spec stops here. Print it
  and say it needs the owner and `/sdlc-loop:spec`.

When the verifier is clean, set `Status: built` on the line under Departures in
`plan.md`, commit it, and say so. Then ask "Continue to deploy now?". On yes,
read `${CLAUDE_PLUGIN_ROOT}/commands/deploy.md` and follow it in this session.
On no, stop.
