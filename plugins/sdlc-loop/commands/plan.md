---
description: Stage 3 — plan the implementation from an accepted spec.md, naming the files that change and the scenarios the work proves.
argument-hint: [optional — which part of the spec to plan]
allowed-tools: Read, Write, Glob, Grep, Bash(date:*), Bash(jq:*), Bash(git log:*), Bash(git status:*), Bash(ls:*), Skill, AskUserQuestion
disallowed-tools: Edit MultiEdit NotebookEdit
---

Plan the work in `spec.md`. Scope: $ARGUMENTS

**Explore and decide. Do not implement.** `allowed-tools` pre-approves the
read-only commands above; it does not stop other tools, so the restriction is
`disallowed-tools` plus this instruction. Write is kept only for `plan.md`. If
you find yourself wanting to change code, the plan is not finished.

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

## Writing it

Read the change's `spec.md`. If it is missing or not `accepted`, say so and
stop. Read the `.feature` files it points at. Then read the code that will
actually change — a plan written from the spec alone names files that do not
exist.

Requirements and design live in `spec.md`. Do not restate them. `plan.md` is at
most 120 lines and carries only decisions, the scenarios it proves and the file
list — no restating of the spec and no narrating of third-party facts, which go
into code comments or a tests assumptions list. If a draft exceeds that, cut
before showing it; if it cannot be cut, the change should be split.

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
path and ask "Continue to Build now?". On yes, Build is yours in this session
against the plan; run the verify commands in `CLAUDE.md` before claiming it
works. On no, stop.
