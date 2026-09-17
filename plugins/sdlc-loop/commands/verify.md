---
description: Fill the verify block in .claude/sdlc.json — the build, test, lint and scenario commands Build runs until green — by proposing each from the repo and running it once.
allowed-tools: Read, Edit, Glob, Grep, Bash, Skill, AskUserQuestion
---

Fill `verify` in this project's `.claude/sdlc.json`.

An agent that cannot tell a healthy run from a broken one will report success
from a failed build. The four commands under `verify` are what Build runs until
green and Test runs once more. They live in the config, not in `CLAUDE.md`: an
agent needs them at Build, not in every session's context.

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

## Doing it

For each of `build`, `test`, `lint` and `scenarios`:

1. Propose the command from what is in the repo — `package.json` scripts, a
   `Makefile`, `pyproject.toml`, CI workflows. Say where you got it.
2. Ask the engineer to confirm or correct it. Do not guess silently.
3. Run it. If it fails now, that is worth knowing now: report it and ask whether
   to record the command anyway.
4. Write it as a string under `verify` in `.claude/sdlc.json`, leaving every
   other key alone.

`scenarios` is the command that runs the `.feature` files through their
bindings. Binding scenarios to a runner is this repo's business — the plugin
ships no runner and no step definitions. If there is none, leave it `null` and
say plainly that the `.feature` files are the acceptance checklist the verifier
reads by hand, and that `/sdlc-loop:spec` will write no bindings until a runner
exists. That is a supported configuration, not a gap.

If `CLAUDE.md` still carries a "Verifying your work" table from an earlier
version of this plugin, offer to remove it: the config is the one source now.

Finish by running all four once more and stating green or red, one line each.
