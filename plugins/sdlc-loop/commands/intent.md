---
description: Stage 1, Plan — write intent.md for a change: the problem, the outcome and the behaviours in plain words; split a programme into children.
argument-hint: [what changes, in a sentence — or --split <NNN> to split an existing intent]
allowed-tools: Read, Write, Glob, Grep, Bash(date:*), Bash(jq:*), Bash(git log:*), Bash(git status:*), Bash(ls:*), Skill, AskUserQuestion
---

Write `intent.md` for: $ARGUMENTS

If that is empty, ask what changes before doing anything else. If it is
`--split <NNN>`, skip to **Splitting** below.

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

Start a new change directory: next free `<NNN>`, a short slug from the subject.
Write `<artifactDir>/<NNN>-<slug>/intent.md` and update `CURRENT`.

This is the originator's document, read by someone deciding whether to fund the
work who will never open the repo. Your job is to get what they mean onto the
page, not to design a solution.

- Interview the owner for what the template asks and the request does not
  answer. Ask about the problem and the behaviours; never ask them to pick an
  implementation.
- Fill `Owner:` with a real person — the one who accepts this and moves the work
  on. If you do not know who, ask. Never leave a placeholder.
- Names of things in the estate, yes — tables, services, repos, by their real
  names from the facts document. Names of code, endpoints or files, no: that is
  design, and it belongs downstream.
- **Behaviours** are one line each, in the originator's words. No
  Given/When/Then here: doing it early hides vague wording instead of exposing
  it, and exposing it is what the design transition is for.
- A change that expresses nothing in Given/When/Then — a refactor, a dependency
  bump, performance work — is first class. Write exactly "No scenario changes.
  The existing scenarios must still pass." and move on. Never invent a behaviour
  to fill the section.
- **Open questions** is for what actually blocks the design. An empty list is a
  good outcome, not a lazy one.

Size comes from scope, not from cutting. The budget below is a signal: if a
draft is over it, say so and say why, and offer to split rather than trimming
the words. Concision comes from the rules: one idea per sentence, no restating
an upstream file, no narrating third-party facts (those go to the facts document
or a code comment), and no section kept for the sake of the template — delete
one with nothing in it.

Budget: about 60 lines.

**The split gate.** One change is one capability, and one capability is one or
two `.feature` files. If the behaviours run past about eight lines, or describe
more than one capability, this is a programme, and the loop handles programmes
by splitting, not by writing a large intent. Say so, propose the split — an
ordered list of children, one capability each, in the order they can ship —
and, when the owner agrees, do what **Splitting** says.

## Showing it

Markdown artefacts are shown by path, never pasted: the owner reads the file.
`.feature` files are the exception and are printed in full, one file at a time,
in a fenced `gherkin` block, every scenario included. Acceptance is the word
"accepted" from the owner; an answer to a scoped question is not acceptance, and
neither is silence. Write nothing to disk that the owner has not seen.

Then ask whether it is accepted. When it is, set `Status: accepted`, print the
path and ask "Continue to design now?". On yes, read
`${CLAUDE_PLUGIN_ROOT}/commands/spec.md` and follow it in this session. On no,
stop.

## Splitting

Given a parent `<NNN>-<slug>/intent.md`, whether just drafted or an old one that
grew too large:

1. Agree the children with the owner: an ordered list, one capability each, one
   line each. Each child inherits the parent's problem by reference.
2. Set the parent's `Status: split` and replace its Behaviours section with a
   `## Children` list of the child directories, in order. Its intent stays as
   the record of why the programme exists.
3. Create each child directory with its own `intent.md`: Problem is one line
   pointing at the parent; Outcome and Behaviours carry only that capability.
   Draft them in order, each through the acceptance step above.
4. Point `CURRENT` at the first child. `CURRENT` never names a split parent.

A parent that already had a spec or plan keeps them; note in the parent which
child each `.feature` file now belongs to, and move nothing until that child's
design transition.

## Parking and rejecting

An intent the owner is not going to pursue now gets `Status: parked`; one they
have decided against gets `Status: rejected`. Either carries one line under the
status line saying why, nothing downstream is written, and `CURRENT` moves to
whatever is active. Never delete the file: the decision is part of the record.
