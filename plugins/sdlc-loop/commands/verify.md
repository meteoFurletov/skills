---
description: Record how to verify work in this repo — build, test, lint and scenario commands with a healthy-output example each — into CLAUDE.md.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, AskUserQuestion
---

Fill in the "Verifying your work" block in this project's `CLAUDE.md`.

An agent that cannot tell a healthy run from a broken one will report success
from a failed build. This block is what stops that, so the healthy-output
examples matter as much as the commands.

## Before anything

Read `.claude/sdlc.json` at the git root. If it is absent, say that this repo has
not run `/sdlc-loop:init` and that the hooks are inert here, then continue with
the defaults `artifactDir: docs/sdlc` and `scenarioGlobs: ["features/**/*.feature"]`.

Artefacts live one directory per change: `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` naming the active one. Take the date from `date +%F`,
never from your own sense of today.

## Loading a template

Read `${CLAUDE_PLUGIN_ROOT}/templates/<name>`. If that path does not exist, fall
back to the install path from
`jq -r '(.plugins // .) | to_entries[]|select(.key|startswith("sdlc-loop@"))|.value[0].installPath' ~/.claude/plugins/installed_plugins.json`
plus `/templates/<name>`. If both fail, say so and stop. Never write a template
from memory — re-deriving it by hand is the drift this plugin exists to stop.

## Doing it

For each of build, test, lint and scenarios:

1. Propose the command from what is in the repo — `package.json` scripts, a
   `Makefile`, `pyproject.toml`, CI workflows. Say where you got it.
2. Ask the engineer to confirm or correct it. Do not guess silently.
3. Run it and record what a healthy run actually printed — the real last line,
   not a paraphrase. If it fails, that is worth knowing now: report it and ask
   whether to record the command anyway.

For scenarios, ask for the command that runs the `.feature` files, and write it
to `scenarioCommand` in `.claude/sdlc.json`. Binding scenarios to a runner is
this repo's business — the plugin ships no runner and no step definitions. If
there is none, set `scenarioCommand` to `null` and record plainly that the
`.feature` files are the acceptance checklist the review pass reads by hand.
That is a supported configuration, not a gap.

Merge the block into `CLAUDE.md` between the `<!-- sdlc-loop:begin -->` and
`<!-- sdlc-loop:end -->` markers, leaving the rest of the file alone. If there
is no `CLAUDE.md`, start from the `CLAUDE.md` template.
