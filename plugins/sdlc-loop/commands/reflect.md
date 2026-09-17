---
description: Reflect — read the proposals inbox, the change directories and the git history, and produce the change list for the next version of the loop, each item routed to the plugin or kept in this project.
argument-hint: [optional — a date to reflect since, or a change directory range]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git log:*), Bash(git show:*), Bash(git diff:*), Bash(git status:*), Bash(jq:*), Bash(date:*), Bash(ls:*), Bash(wc:*), Agent, Skill, AskUserQuestion
---

Reflect on how the loop has run here. Scope: $ARGUMENTS

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

## What to read

1. `<artifactDir>/PROPOSALS.md` — every entry whose route is still `open`.
   These are corrections the owner already made twice; they come first.
2. The change directories in scope: each intent, spec and plan, their sizes
   against the budgets, their status lines, which sections were dropped or
   invented, and whether each links upstream or restates it.
3. The git history in scope: how many commits amended `plan.md` after the plan
   was accepted, and whether those were re-decisions or bookkeeping; every
   `.feature` file modified, deleted or recreated, and whether a `spec.md`
   moved with it; how long each change took, stage by stage, where the
   timestamps allow it.
4. The facts document: which names in it were added after a correction.

Use subagents for 2 and 3 when the scope is more than a few changes; ask each
for evidence with paths and numbers, never for fixes.

## Then the owner

Before proposing anything, ask the owner for their own notes: where it dragged,
where a gate got in the way, what they asked for by hand every time, what they
would not give up. Their reading outranks the evidence; the evidence checks it.

## The change list

Produce a numbered list. Each item is one change to how the loop works, with
the evidence behind it in one line, and a route:

- **plugin** — a rule that would hold in any repo. It changes a command, a
  template, a hook or the README of the plugin, in the next version.
- **project** — a fact, a name or a convention of this estate. It goes to the
  facts document, `CLAUDE.md` or a project skill, now.
- **dropped** — with the reason.

Show the list and let the owner accept, strike or re-route each item. Then:

- Apply every `project` item here, in this session.
- Write every `plugin` item back into `PROPOSALS.md` with `Route: plugin` and
  the version it is meant for, so the plugin's own reflect run can pick it up.
  The plugin repo is not this repo; do not edit it from here.
- Mark the rest `dropped`, with the reason, and leave them in the file.

The loop's own history is part of the record. Never delete an entry.
