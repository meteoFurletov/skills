---
description: Set this repo up for the sdlc-loop — opt-in marker, the facts document, the proposals inbox, starter CLAUDE.md and review policy, and optionally the deploy gate and Stage 6 detector.
argument-hint: "[--artifacts] [--hooks] [--gate] [--watch]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, AskUserQuestion
---

Set this repository up for the sdlc-loop. Flags: $ARGUMENTS

With no flags, do `--artifacts` and `--hooks` — the two that need no CI and no
monitoring. The flags are additive and re-running any of them is safe. Say at the
start which you are doing, so the user is never guessing.

**Never overwrite.** Merge into what is there. If a file exists and merging would
change a line you did not write, report the collision — the file and the line —
and stop. Leave the repo as you found it.

## Loading a template

Read `${CLAUDE_PLUGIN_ROOT}/templates/<name>`. If that path does not exist, fall
back to the install path from
`jq -r '(.plugins // .) | to_entries[]|select(.key|startswith("sdlc-loop@"))|.value[0].installPath' ~/.claude/plugins/installed_plugins.json`
plus `/templates/<name>`. If both fail, say so and stop. Never write a template
from memory — re-deriving it by hand is the drift this plugin exists to stop.

### --artifacts

Ask where artefacts should live (default `docs/sdlc`) and create it. Then:

- Merge the `CLAUDE.md` template between its `<!-- sdlc-loop:begin -->` and
  `<!-- sdlc-loop:end -->` markers, so re-running updates that block and touches
  nothing else; substitute the real paths for `<artifacts-dir>` and
  `<facts-doc>`. If the block from an earlier version carries a "Verifying your
  work" table, replace the whole block: the verify commands live in
  `.claude/sdlc.json` now.
- Write the facts document from the `estate.md` template at the path the owner
  chooses (default `docs/estate.md`), with the owner's name. Ask for the names
  that keep getting corrected in this estate and put them in now; an empty
  Names section on day one is how the corrections start.
- Write `<artifactDir>/PROPOSALS.md` from its template.
- Write `.github/copilot-instructions.md` from the `copilot-instructions.md`
  template, with the owner's name, and `REVIEW.md` from its template. Tell the
  owner that Copilot code review reads the former on every pull request, and
  that a repository ruleset with automatic Copilot review is what makes
  `/sdlc-loop:deploy` need no manual request.

### --hooks

Write `.claude/sdlc.json` from the `sdlc.json` template. This one file is the
opt-in: the plugin registers its hooks in every session, and each hook's first
act is to look for this file and do nothing if it is absent. Nothing is copied
into the repo, so upgrading the plugin upgrades this repo's gates. Deleting the
file turns them off.

Set from what the repo actually looks like:

- `scenarioGlobs` — where `.feature` files are. Look for existing ones; if there
  are none, ask where they will go.
- `artifactDir` and `artifactPaths` — the artefact directory plus the facts
  document, `CLAUDE.md`, `REVIEW.md`, `.github/copilot-instructions.md` and
  `.claude/sdlc.json`. These are artefacts living outside the artefact
  directory, and leaving them out makes `plan-sync` block every commit that
  touches them.
- `facts` — the facts document's path.
- `deploy` — `"pr"` where changes go through a pull request on GitHub;
  `"manual"` where this repo's landing pipeline is its own and the loop only
  prints it.
- `verify` — leave the four entries `null`; `/sdlc-loop:verify` fills them.

A file from version 1 of this plugin (no `version`, or `version: 1`) is
upgraded in place: add the missing keys with these defaults, move
`scenarioCommand` into `verify.scenarios`, and say what moved.

Globs take `*`, `?` and `**`. Brace expansion is not supported.

Then say what the three build-time hooks do, one sentence each:
`protect-scenarios` blocks an Edit or Write over an existing `.feature` file and
allows new ones; `scenario-commit` blocks a commit that modifies or deletes an
existing `.feature` file unless the active change's `spec.md` is staged with it,
whatever tool wrote the file; `plan-sync` blocks a commit touching files absent
from the `Files that change` list in `plan.md` unless `plan.md` is staged with
it. All three allow and explain themselves when they cannot establish their
condition, and none ever pauses for a human.

### --gate

Add a `gate` object to `.claude/sdlc.json`. Ask for these and guess at none:

- `approver` — the person a production release waits for, by name.
- `deployPatterns` — shell-glob patterns matching this repo's production deploy
  commands (`*` crosses `/` here; these match a command line, not a path).
  Propose them from the repo's own workflows and scripts and have the owner
  confirm. No script can tell production from staging, so these patterns *are*
  the definition of production — too broad makes the gate noise, too narrow makes
  it decoration.
- `authorisation` — optionally, what authorisation looks like here.

This is the only hook that pauses for a human, and it is out of the Build path by
construction.

### --watch

Hand off to `/sdlc-loop:watch`, which checks its own preconditions and refuses
clearly if they do not hold.

### Finally

Print what changed, what did not, and the next command — normally
`/sdlc-loop:verify`, then `/sdlc-loop:intent` for the first change.
