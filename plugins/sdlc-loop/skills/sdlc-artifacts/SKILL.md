---
name: sdlc-artifacts
description: Use when writing or updating an SDLC artefact — intent.md, spec.md, plan.md, or a Gherkin .feature file — in a repo carrying .claude/sdlc.json, and no /sdlc-loop command was typed. Covers the house rules those artefacts must follow (link upstream instead of restating it, name one owner, write short and stop, scenarios change only at the spec transition), and where the shipped templates live so a command can find them. Triggers include "write the intent for this", "turn that into a spec", "add a scenario", "update the plan", "what should the spec say". Do NOT use for ordinary READMEs or design docs outside the loop.
---

# SDLC artefacts

This repo runs the six-stage loop. When someone asks for one of its artefacts in
prose rather than through `/sdlc-loop:<transition>`, the rules below still apply.

Read `.claude/sdlc.json` at the git root for `artifactDir` and `scenarioGlobs`.
No such file means the repo has not opted in — write what was asked for and skip
the rest of this.

Prefer the command where one fits. `/sdlc-loop:intent`, `:spec` and `:plan` carry
the whole transition including the approval step. This skill is for the times
nobody typed one.

## Where the templates are

The plugin's templates are at `../../templates/` relative to this skill's base
directory, which is stated at the top of this prompt. That path is the reliable
route to them: a slash command's body is not interpolated, so a command that
needs a template invokes this skill and reads the directory from here.

```
templates/
  intent.md          Stage 1
  spec.md            Stage 2
  scenario.feature   Stage 2, one per capability
  plan.md            Stage 3
  CLAUDE.md          the starter block init merges into the project
  REVIEW.md          the starter review policy
  bands.yaml         Stage 6 detection bands
  sdlc.json          the opt-in marker
  sdlc-watch.yml     the scheduled detector workflow
```

Never reconstruct a template from memory. Re-deriving it by hand in each repo is
exactly the drift this plugin exists to stop.

## The rules

**Link upstream, never restate it.** `spec.md` opens by pointing at `intent.md`
and adds only what is new. `plan.md` points at both. A summary of an upstream
artefact is a second copy that will drift — cite the file instead. This is the
single biggest thing keeping these documents readable.

**Write short and stop.** These are read by a person making a decision, and an
artefact nobody finishes reading gates nothing. Cut a section that has nothing in
it rather than padding it. Nothing measures this; it is a property of the
writing, not a limit.

**Name a real owner.** Every artefact carries `Owner:` — the one person who
accepts it and moves the work on. If you do not know who, ask. A placeholder
owner means nobody accepted it.

**Scenarios are the contract.** `.feature` files change at the spec transition
and nowhere else, and a hook blocks edits to an existing one. New behaviour gets
a new scenario at the spec transition — do not add one while implementing, and
never edit an existing one to match what the code turned out to do. Unit tests
are the opposite: implementation detail, free to churn, and never evidence on
their own that a scenario holds.

**Gherkin regardless of runner.** Write Given/When/Then whether or not the repo
can execute it, so a repo that adds a runner later needs no rewrite. Where there
is none, the `.feature` files are the acceptance checklist the review pass reads
by hand.

**A change with no scenarios is first class.** Refactors, dependency bumps and
performance work express nothing in Given/When/Then. They say "No scenario
changes. The existing scenarios must still pass." and that is the whole
requirement on them. Never invent a scenario to fill a section.

## Layout

Artefacts live one directory per change: `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` holding the active directory name. Keep that pointer
current — `plan-sync` reads it to find the plan a commit is measured against.
