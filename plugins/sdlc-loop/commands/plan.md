---
description: Stage 3 — plan the implementation from an accepted spec.md, naming the files that change and the scenarios the work proves.
argument-hint: [optional — which part of the spec to plan]
allowed-tools: Read, Write, Glob, Grep, Bash(date:*), Bash(jq:*), Bash(git log:*), Bash(git status:*), Bash(ls:*), Skill, AskUserQuestion
---

Plan the work in `spec.md`. Scope: $ARGUMENTS

**Explore and decide. Do not implement.** This command has no edit or general
shell access by design — slash-command frontmatter cannot request plan mode, so
the restriction is the tool list plus this instruction. If you find yourself
wanting to change code, the plan is not finished.

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

Read the change's `spec.md`. If it is missing or not `accepted`, say so and
stop. Read the `.feature` files it points at. Then read the code that will
actually change — a plan written from the spec alone names files that do not
exist.

Requirements and design live in `spec.md`. Do not restate them.

Two sections earn their place by being read by something downstream:

- **Scenarios this work proves** — the `.feature` files and scenario names this
  change is accountable for. If the spec declared none, say so here too. New
  behaviour never gets a new scenario at this stage; if you find behaviour with
  no scenario, stop and go back to `/sdlc-loop:spec`.
- **Files that change** — repo-relative paths, one per line, no prose. The
  `plan-sync` hook reads this list, so it has to be real. A directory path
  covers everything beneath it. Roughly right matters more than exactly right: a
  departure is fine, an unnoticed departure is not.

Present the plan for approval. Once approved, write
`<artifactDir>/<NNN>-<slug>/plan.md`, confirm `CURRENT` points at it, print the
path and stop. Build is a separate run.
