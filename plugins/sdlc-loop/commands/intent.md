---
description: Stage 1 — write intent.md for a change: the problem, the outcome, and the scenarios in plain words.
argument-hint: [what changes, in a sentence]
allowed-tools: Read, Write, Glob, Grep, Bash(date:*), Bash(jq:*), Bash(git log:*), Bash(git status:*), Bash(ls:*), Skill, AskUserQuestion
---

Write `intent.md` for: $ARGUMENTS

If that is empty, ask what changes before doing anything else.

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

Start a new change directory: next free `<NNN>`, a short slug from the subject.
Write `<artifactDir>/<NNN>-<slug>/intent.md` and update `CURRENT`.

This is the originator's document. Your job is to get what they mean onto the
page, not to design a solution.

- Interview the owner for whatever the template asks and the request does not
  answer. Ask about the problem and the scenarios; never ask them to pick an
  implementation.
- Fill `Owner:` with a real person — the one who accepts this and moves the work
  on. If you do not know who, ask. Never leave a placeholder.
- **Scenarios** are behaviours in the originator's own words, one line each. No
  Given/When/Then here: doing it early hides vague wording instead of exposing
  it, and exposing it is what the spec transition is for.
- A change that expresses nothing in Given/When/Then — a refactor, a dependency
  bump, performance work — is first class. Write exactly "No scenario changes.
  The existing scenarios must still pass." and move on. Never invent a scenario
  to fill the section.
- **Open questions** is for what actually blocks the spec. An empty list is a
  good outcome, not a lazy one.

Write what is essential and stop. Delete a section with nothing in it rather than
padding it — this is read by a person deciding whether to fund the work. At most
100 lines: if a draft exceeds that, cut before showing it, and if it cannot be
cut, the change should be split.

Then show the owner what you wrote and ask whether it is accepted. When it is,
set `Status: accepted`, print the path and ask "Continue to spec now?". On yes,
read `${CLAUDE_PLUGIN_ROOT}/commands/spec.md` and follow it in this session. On
no, stop.
