---
description: Set this repo up for the sdlc-loop — opt-in marker, starter CLAUDE.md and REVIEW.md, and optionally the deploy gate and Stage 6 detector.
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

### --artifacts

Ask where artefacts should live (default `docs/sdlc`) and create it. Merge the
`CLAUDE.md` template between its `<!-- sdlc-loop:begin -->` and
`<!-- sdlc-loop:end -->` markers, so re-running updates that block and touches
nothing else; substitute the real directory for `<artifacts-dir>`. Add the
`REVIEW.md` template the same way, with the owner's name filled in.

Leave the "Verifying your work" placeholders alone and say that
`/sdlc-loop:verify` fills them in by interview.

### --hooks

Write `.claude/sdlc.json` from the `sdlc.json` template. This one file is the
opt-in: the plugin registers its hooks in every session, and each hook's first
act is to look for this file and do nothing if it is absent. Nothing is copied
into the repo, so upgrading the plugin upgrades this repo's gates. Deleting the
file turns them off.

Set from what the repo actually looks like:

- `scenarioGlobs` — where `.feature` files are. Look for existing ones; if there
  are none, ask where they will go.
- `artifactDir` and `artifactPaths` — the artefact directory plus `CLAUDE.md`,
  `REVIEW.md` and `.claude/sdlc.json`. These last three are artefacts living at
  the repo root, and leaving them out makes `plan-sync` block every commit that
  touches them.

Globs take `*`, `?` and `**`. Brace expansion is not supported.

Then say what the two build-time hooks do, one sentence each: `protect-scenarios`
blocks writes over an existing `.feature` file and allows new ones, because
scenarios change at the spec transition and belong to the owner; `plan-sync`
blocks a commit touching files absent from the `Files that change` list in
`plan.md` unless `plan.md` is staged with it. Both allow and explain themselves
when they cannot establish their condition, and neither ever pauses for a human.

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
