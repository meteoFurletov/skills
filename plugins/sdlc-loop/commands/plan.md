---
description: Stage 3, Build, first half — plan the implementation from an accepted spec.md in plan mode, naming the files that change and the scenarios the work proves.
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

## Writing it

Read the change's `spec.md`. If it is missing or not `accepted`, say so and
stop. Read the `.feature` files it points at and their bindings. Then read the
code that will actually change — a plan written from the spec alone names files
that do not exist.

Requirements and design live in `spec.md`. Do not restate them. `plan.md`
carries decisions, the scenarios it proves, the file list, the risks, and an
empty Departures section for Build to fill.

Two sections earn their place by being read by something downstream:

- **Scenarios this work proves** — the `.feature` files and scenario names this
  change is accountable for. If the spec declared none, say so here too. New
  behaviour never gets a new scenario at this stage; if you find behaviour with
  no scenario, stop and go back to `/sdlc-loop:spec`.
- **Files that change** — repo-relative paths, one per line, no prose. The
  `plan-sync` hook reads this list, so it has to be real. A directory path
  covers everything beneath it, but a list that is only directories tells the
  reader nothing: name the files you expect, and let a departure be a departure.
  A path in another repo is listed under its own sub-heading and is not
  checked by the hook.

Size comes from scope, not from cutting. The budget below is a signal: if a
draft is over it, say so and say why, and offer to split rather than trimming
the words. Concision comes from the rules: one idea per sentence, no restating
an upstream file, no narrating third-party facts (those go to the facts document
or a code comment), and no section kept for the sake of the template — delete
one with nothing in it.

Budget: about 100 lines.

## Showing it

Markdown artefacts are shown by path, never pasted: the owner reads the file.
`.feature` files are the exception and are printed in full, one file at a time,
in a fenced `gherkin` block, every scenario included. Acceptance is the word
"accepted" from the owner; an answer to a scoped question is not acceptance, and
neither is silence. Write nothing to disk that the owner has not seen.

Present the plan by path. The owner's read is the gate for this stage: they may
say accepted, or ask for a change. Accepting the plan is the decision to build
it — there is no second question. Once accepted, write
`<artifactDir>/<NNN>-<slug>/plan.md` with `Status: accepted`, confirm `CURRENT`
points at it, print the path, then read `${CLAUDE_PLUGIN_ROOT}/commands/build.md`
and follow it in this session. Stop only if the owner says to build later.
