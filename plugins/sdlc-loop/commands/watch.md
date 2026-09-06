---
description: Stage 6 — scaffold the CI failure-rate detector into this repo: bands.yaml, the watcher script and a scheduled workflow.
argument-hint: [optional — cron schedule, e.g. "0 6 * * *"]
allowed-tools: Read, Write, Glob, Grep, Bash, Skill, AskUserQuestion
---

Scaffold the Stage 6 detector. Schedule: $ARGUMENTS (default `0 6 * * *`)

## Preconditions

Check both and refuse clearly if either fails. A detector with no stable baseline
is worse than none, because it teaches people to ignore it.

1. `gh` is on PATH and authenticated (`gh auth status`).
2. At least 30 calendar days of CI history, **and** at least 20 distinct days
   carrying 3 or more runs. Check with
   `gh run list --limit 300 --json conclusion,createdAt`. Either alone admits a
   useless baseline. If it falls short, say by how much and stop.

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

## Scaffolding

Copy, never overwriting — report a collision and stop:

| From | To |
| --- | --- |
| `templates/bands.yaml` | `.sdlc/bands.yaml` |
| `templates/intent.md` | `.sdlc/intent-template.md` |
| `scripts/watch.py` | `scripts/sdlc-watch.py` |
| `templates/sdlc-watch.yml` | `.github/workflows/sdlc-watch.yml` |

Substitute `artifactDir` for `<artifacts-dir>` in the workflow and set the cron.
Record a `watch` object in `.claude/sdlc.json` carrying the paths and the
`scriptVersion` header from `watch.py`.

Then take one live reading — run `scripts/sdlc-watch.py` once — so the owner
sees the current mean and standard deviation before trusting the thing.

## What to tell the owner

In a sentence each: detection is deterministic and no model runs in it; a
2-sigma breach invokes Claude read-only and writes the result back as a draft
`intent.md` for a human to claim; a 3-sigma breach also opens a PR carrying it;
the workflow needs an `ANTHROPIC_API_KEY` repository secret before the diagnose
step will run; and this is the one part of the plugin copied into the repo, so
re-run `/sdlc-loop:watch` after upgrading the plugin.
