# sdlc-loop

A six-stage AI-native SDLC carried as a Claude Code plugin, so the process is
fixed in one place instead of re-derived by hand in every repo. Commands for the
stage transitions, two skills for when nobody types a command, and three hooks
for the rules that must hold rather than be advised.

Project-agnostic: no language, stack, framework or domain assumption anywhere in
it. All state is plain markdown, Gherkin and YAML in the project's own git.

```
commands/        one per stage transition, plus init
skills/
  sdlc-artifacts        the house rules, for prose asks; also where commands
                        resolve the shipped templates from
  sdlc-watch-writeback  the headless Stage 6 diagnosis
templates/       the nine shipped artefacts, read on demand
hooks/           hooks.json registers all three; each is inert without opt-in
scripts/watch.py the Stage 6 detector — stdlib + gh, no model in the path
tests/run.sh     every hook blocking and silent, every detection rule; no network
```

## Install

```bash
claude plugin marketplace add meteoFurletov/skills
claude plugin install sdlc-loop@meteof-skills
```

Then, in a repo you want to run the loop in:

```
/sdlc-loop:init
```

`init` writes an opt-in marker, a starter `CLAUDE.md` block and a starter
`REVIEW.md`. It merges with what is there and never overwrites; on a conflict it
reports and stops. Adopt one play at a time with `--artifacts`, `--hooks`,
`--gate` and `--watch` — a repo with no CI and no monitoring can run everything
except `--watch`.

## The loop

| Command | Stage | Writes |
| --- | --- | --- |
| `/sdlc-loop:intent` | 1 — what changes and why | `intent.md` |
| `/sdlc-loop:spec` | 2 — requirements and the contract | `spec.md` + `.feature` |
| `/sdlc-loop:plan` | 3 — approach and files that change | `plan.md` |
| — | 4 — Build, against the plan | code |
| `/sdlc-loop:review` | 5 — the compliance pass | findings |
| `/sdlc-loop:watch` | 6 — CI drift detection | `bands.yaml`, workflow |
| `/sdlc-loop:verify` | any — how to tell a healthy run | `CLAUDE.md` block |

Two things keep the artefacts readable. Each links upstream instead of restating
it, so `spec.md` cites `intent.md` rather than summarising it. And every artefact
names one owner — the person who accepts it and moves the work on.

Artefacts live one directory per change, `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` naming the active one. `plan-sync` reads that pointer to
find the plan a commit is measured against.

## Scenarios are the contract

The spec transition turns each plain-words behaviour from the intent into a
Gherkin `.feature` file. That file is what Build builds against and what the
review pass checks the diff against. It is written whether or not the repo can
execute it, so adding a runner later needs no rewrite — the plugin ships no
runner and no step definitions, because that binding is per-repo.

Unit tests are the opposite: implementation detail, free to churn, and never
evidence on their own that a scenario holds.

## Hooks

Registered by the plugin in every session, and inert in any repo without a
`.claude/sdlc.json`. Each script's first act is to look for that file and exit if
it is absent, so opting in is one file and upgrading the plugin upgrades every
opted-in repo at once — no copies to drift.

| Hook | Fires on | Blocks |
| --- | --- | --- |
| `protect-scenarios` | `Edit`/`Write`/`MultiEdit` | A write over an **existing** `.feature` file. New ones pass. |
| `plan-sync` | `Bash`, `git commit` | A commit touching files absent from `plan.md`'s *Files that change*, unless `plan.md` is staged with it. |
| `deploy-gate` | `Bash` | Nothing — it *asks*. Only active once `init --gate` writes a `gate` object. |

The first two allow or block with no human in the path. `deploy-gate` is the only
one that pauses, and it is out of the Build path by construction. A hook that
cannot establish its condition allows the action and says why — ambiguity never
blocks, and none of them ever returns an explicit `allow`, which would bypass
your own permission settings. A block prints what it stopped, the rule, and the
route through it.

**Why `protect-scenarios` allows creation.** Blocking every write to a `.feature`
path would close the escape route it points at: `/sdlc-loop:spec` has to write
those files itself. So creation passes and modification is denied. Replacing a
scenario means `git rm` then a fresh write, which leaves a visible delete+add in
the diff — and the starter `REVIEW.md` lists exactly that pair as something to
check, because it is the one way round this gate.

Artefact concision, linking upstream, the owner field and scenario coverage are
deliberately *not* hooks. None has a test a script can run without guessing at
intent, and a gate that guesses is a gate that gets switched off.

## `.claude/sdlc.json`

| Key | Meaning |
| --- | --- |
| `artifactDir` | Where change directories live. Default `docs/sdlc`. |
| `artifactPaths` | Globs `plan-sync` never requires a plan entry for. Must include `CLAUDE.md` and `REVIEW.md`, which are artefacts living at the repo root. |
| `scenarioGlobs` | What `protect-scenarios` protects. |
| `scenarioCommand` | Written by `/sdlc-loop:verify`. `null` means no runner — the `.feature` files are the acceptance checklist. |
| `gate` | Absent unless `init --gate` ran. Holds `approver` and `deployPatterns`. |
| `watch` | Absent unless `init --watch` ran. |

Globs take `*`, `?` and `**`. Brace expansion is not supported. `deployPatterns`
are shell globs matched against a command line, so `*` crosses `/` there.

## Stage 6

`scripts/watch.py` pulls CI history with `gh`, computes a daily failure rate, and
applies Western Electric rules over a rolling mean and standard deviation,
matched against a version-controlled `bands.yaml`. No model runs in the detection
path. 1σ logs; 2σ invokes Claude read-only to diagnose and writes the result back
as a draft `intent.md`; 3σ additionally opens a PR carrying it.

Detection is one-sided — CI becoming more reliable is not an incident — and a
flat line short-circuits rather than dividing by a zero standard deviation.

`bands.yaml` is read by a restricted parser, because python3 stdlib has no YAML.
The shipped file states the subset it may use in its first comment.

The diagnosis run gets no write tools, and the script compares `git status`
before and after, reverting if anything else moved. "Writes back an intent and
nothing else" is not something prompting can guarantee.

`init --watch` requires `gh`, at least 30 calendar days of CI history **and** at
least 20 days carrying 3 or more runs, and refuses otherwise rather than
installing a detector with no stable baseline.

Stage 6 is the one part of this plugin copied into the project — GitHub Actions
cannot see your plugin cache. Re-run `/sdlc-loop:watch` after upgrading.

## Tests

```bash
bash tests/run.sh
```

A scratch git repo per case, no network and no `gh`. Every hook is exercised both
blocking and staying silent, and every detection rule in isolation.

## Requirements

`bash` and `jq` for the hooks. `python3` (stdlib only) and `gh` for the watcher.
