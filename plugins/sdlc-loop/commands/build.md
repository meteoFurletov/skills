---
description: Stage 3, Build, second half — implement an accepted plan.md and run the verify commands until they are green, without stopping for anything the plan already settled.
argument-hint: [optional — the change directory to build]
allowed-tools: Read, Write, Edit, MultiEdit, Glob, Grep, Bash, Agent, Skill
---

Build the change: $ARGUMENTS

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

## What you build against

Read, in this order: `plan.md` (must be `accepted`; otherwise say so and stop),
`spec.md`, every `.feature` file the plan proves, their bindings, and the
`verify` block in `.claude/sdlc.json`. The plan is the approach and the file
list; the spec is the requirements; the scenarios and their Then assertions are
what done means. Nothing else in context outranks these.

If the `verify` block is empty, run `/sdlc-loop:verify` first — a build with no
way to check itself reports success from a failed run.

## The loop

Implement the plan's approach, then run the verify commands — build, test, lint,
scenarios — and fix what is red, and run them again, until all four are green.
Do not ask the owner anything the plan, the spec or the scenarios already
settle. The owner accepted the intent, the spec and the plan so that this stage
can run without them.

Rules that hold throughout:

- **Glue, never assertions.** A binding's `Given` and `When` may change to reach
  the code as it turns out to be. A `Then` assertion may not. If an assertion is
  wrong, that is a finding against the design: stop, say which one and why, and
  go no further until the owner takes it back through `/sdlc-loop:spec`.
- **Scenarios are not yours.** Never write, edit, delete or recreate a
  `.feature` file here. The hooks block it; if you find a way round them, that
  is a bug in the hooks, not permission.
- **Departures are recorded, not hidden.** When the approach or the file list
  turns out wrong, append one line to Departures in `plan.md` saying what and
  why, stage `plan.md` with the commit that departs, and continue. A departure
  that changes what the spec requires is not yours to make: stop and say so.
- **New behaviour with no scenario stops the build.** It gets a scenario at the
  design transition or it does not get built.
- Commit as you go in this repo's convention. A red verify run is never
  committed as done.

## When green

Say what was built in a few lines, by path, then read
`${CLAUDE_PLUGIN_ROOT}/commands/test.md` and follow it in this session. Build is
not finished until Test has run.
