---
description: Stage 2 — turn an accepted intent.md into spec.md plus the Gherkin .feature files that are the executable contract.
argument-hint: [optional — the change directory to work in]
allowed-tools: Read, Write, Glob, Grep, Bash(date:*), Bash(jq:*), Bash(git rm:*), Bash(git status:*), Bash(ls:*), Skill, AskUserQuestion
---

Write `spec.md` and its `.feature` files. Change: $ARGUMENTS

If that is empty, use `<artifactDir>/CURRENT`.

## Before anything

Read `.claude/sdlc.json` at the git root. If it is absent, say that this repo has
not run `/sdlc-loop:init` and that the hooks are inert here, then continue with
the defaults `artifactDir: docs/sdlc` and `scenarioGlobs: ["features/**/*.feature"]`.

Artefacts live one directory per change: `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` naming the active one. Take the date from `date +%F`,
never from your own sense of today.

## Loading a template

Try in order, and say which route worked:

1. `.claude/sdlc/templates/<name>` in the project.
2. Invoke the `sdlc-artifacts` skill. Its prompt states its base directory, and
   the templates sit at `<base>/../../templates/`. This is the primary route — a
   command body is not interpolated, so `${CLAUDE_PLUGIN_ROOT}` is not available
   here and neither is it in the shell environment.
3. `jq -r '(.plugins // .) | to_entries[]|select(.key|startswith("sdlc-loop@"))|.value[0].installPath' ~/.claude/plugins/installed_plugins.json`,
   then probe both `<installPath>/templates/` and `<installPath>/plugins/sdlc-loop/templates/`.
4. `plugins/sdlc-loop/templates/` under the current git root.

If all four fail, say which you tried and stop. Never write a template from
memory — re-deriving it by hand is the drift this plugin exists to stop.

## Writing it

Read the change's `intent.md`. If it is missing, or its status is not
`accepted`, say so and stop — a spec written against an unaccepted intent
specifies something nobody agreed to.

**Link upstream, never restate it.** Problem, rationale and constraints live in
the intent. `spec.md` opens by pointing at it and then adds only what is new:
requirements, design, non-goals, acceptance. If you catch yourself summarising
the intent, delete the summary and cite the file.

**The scenarios are the point of this transition.** Turn each plain-words
behaviour from the intent into Gherkin in a `.feature` file committed alongside:

- One `Feature` per capability, named for the capability and not the
  implementation. One action per `When`, an observable result per `Then`.
- Write Gherkin whether or not this repo can execute it, so a repo that adds a
  runner later needs no rewrite.
- This is where vague wording becomes concrete and the owner sees what the change
  actually commits to. If a behaviour will not go into Given/When/Then without
  inventing detail, that is a finding — take it back to the owner, do not guess.
- Where the intent declares no scenario changes, record that in `spec.md`, write
  no `.feature` file, and note the existing scenarios must still pass.

**Replacing an existing scenario.** The `protect-scenarios` hook blocks writes
over an existing `.feature` file, including here. To replace one, `git rm` it
and write a fresh file. That is deliberate: it leaves a visible delete+add in the
diff, which is what the review pass looks for.

Requirements are numbered, testable, one line each. **Non-goals** is what this
deliberately does not do. **Flagged concerns** is what the owner should see
before Build. Cut any section the plan will not read.

Show the owner the scenarios first and the spec second, and ask whether it is
accepted. When it is, set `Status: accepted`. Print the paths and stop.
