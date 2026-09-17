# sdlc-loop

The six-stage AI-native SDLC playbook carried as a Claude Code plugin, so the
process is fixed in one place instead of re-derived by hand in every repo.
Commands for the stage transitions, two skills for when nobody types a command,
four hooks for the rules that must hold rather than be advised, and a reflect
step that turns what a repo learned into the next version of the loop.

Project-agnostic: no language, stack, framework or domain assumption anywhere in
it. All state is plain markdown, Gherkin and YAML in the project's own git.

```
commands/        one per stage transition, plus init, verify and reflect
skills/
  sdlc-artifacts        the house rules, for prose asks
  sdlc-watch-writeback  the headless Stage 6 diagnosis
templates/       the twelve shipped artefacts, read via ${CLAUDE_PLUGIN_ROOT}
hooks/           hooks.json registers all four; each is inert without opt-in
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

`init` writes an opt-in marker, the facts document, the proposals inbox, a
starter `CLAUDE.md` block and the review policy. It merges with what is there
and never overwrites; on a conflict it reports and stops. Adopt one play at a
time with `--artifacts`, `--hooks`, `--gate` and `--watch`.

## The loop

The stages are the playbook's, numbered as it numbers them.

| Stage | Command | Writes | Gate |
| --- | --- | --- | --- |
| 1 Plan | `/sdlc-loop:intent` | `intent.md` | the owner says accepted |
| 2 Design | `/sdlc-loop:spec` | `spec.md`, `.feature` files, bindings written red | the owner reads every scenario in full |
| 3 Build | `/sdlc-loop:plan`, then `/sdlc-loop:build` | `plan.md`, code | the owner's read of the plan; then nothing until green |
| 4 Test | `/sdlc-loop:test` | nothing — a fix or a stop, then `Status: built` | a verifier that did not write the code |
| 5 Deploy | `/sdlc-loop:deploy` | the pull request, fixes from its review | Copilot code review; the code owner merges |
| 6 Maintain | `/sdlc-loop:watch` | `bands.yaml`, the detector | a metric breach becomes a draft `intent.md` |
| any | `/sdlc-loop:verify` | the `verify` block in `.claude/sdlc.json` | — |
| any | `/sdlc-loop:reflect` | the change list for the next version | the owner routes each item |

```mermaid
flowchart LR
  F[facts document] -.-> I & S & P
  I[1 intent.md] --> S[2 spec.md + .feature + red bindings] --> P[3 plan.md] --> B[3 build until green] --> T[4 verifier] --> D[5 PR + Copilot review]
  T -. findings .-> B
  I -. split .-> I
  D --> M[6 breach → intent.md] -.-> I
  R[PROPOSALS.md → reflect] -.-> next[next version]
```

Stages chain in one session on request: once its artefact is accepted, each
stage offers to continue to the next, and Build runs into Test on its own.

Three things keep the artefacts short. Each links upstream instead of restating
it. Every artefact names one owner. And size comes from scope: one change is one
capability, one or two `.feature` files, and an intent that needs more is split
into children rather than cut — the parent stays with `Status: split`.

Artefacts live one directory per change, `<artifactDir>/<NNN>-<slug>/`, with
`<artifactDir>/CURRENT` naming the active one. The commit hooks read that
pointer to find the plan and the spec a commit is measured against.

## The facts document

Every stage reads it before drafting. It holds the estate's real names, the
facts the code does not say, and how changes land — repos, merge order, what to
run after. A name corrected in chat twice goes there once, and a scenario that
spells a system differently from that file is wrong before the owner reads it.

## Scenarios are the contract

The design transition turns each plain-words behaviour from the intent into a
Gherkin `.feature` file, in production's words, and — where the repo has a
runner — writes the step definitions at the same time, red. Each `Then` asserts
the observable result; `Given` and `When` reach code that may not exist yet.
Build's job is to turn them green by changing code and binding glue, never an
assertion. Test's verifier diffs the bindings against the design commit to see
that it did not.

Unit tests are the opposite: implementation detail, free to churn, and never
evidence on their own that a scenario holds.

## Test produces a fix or a stop

The verifier is a subagent with a fresh context. It checks the spec against the
scenarios, the scenarios against their bindings, the code against the spec, and
the plan against what was touched. It writes no file: a finding in code goes
back to Build and is fixed; a finding against a scenario, an assertion or the
spec stops the loop for the owner. The pull request's review is the record.

## Deploy

The agent that wrote the code does not approve it. `/sdlc-loop:deploy` opens
the pull request, Copilot code review applies `.github/copilot-instructions.md`
to it — requested automatically by a repository ruleset — and the command
addresses every finding: fix, reply why not, record a departure, or stop when a
comment asks for the contract to change. Merging stays with the code owner, and
how the change lands is printed from the facts document, because a landing
pipeline is a repo's own.

## Hooks

Registered by the plugin in every session, and inert in any repo without a
`.claude/sdlc.json`. Each script's first act is to look for that file and exit if
it is absent, so opting in is one file and upgrading the plugin upgrades every
opted-in repo at once — no copies to drift.

| Hook | Fires on | Blocks |
| --- | --- | --- |
| `protect-scenarios` | `Edit`/`Write`/`MultiEdit` | A write over an **existing** `.feature` file. New ones pass. |
| `scenario-commit` | `Bash`, `git commit` | A commit that modifies, deletes or renames an existing `.feature` file, unless the active change's `spec.md` is staged with it. New files pass. |
| `plan-sync` | `Bash`, `git commit` | A commit touching files absent from `plan.md`'s *Files that change*, unless `plan.md` is staged with it. |
| `deploy-gate` | `Bash` | Nothing — it *asks*. Only active once `init --gate` writes a `gate` object. |

The first three allow or block with no human in the path. `deploy-gate` is the
only one that pauses, and it is out of the Build path by construction. A hook
that cannot establish its condition allows the action and says why — ambiguity
never blocks, and none of them ever returns an explicit `allow`, which would
bypass your own permission settings. A block prints what it stopped, the rule,
and the route through it.

**Why two scenario hooks.** `protect-scenarios` sees the Edit and Write tools
and nothing else; an agent working through the shell rewrites a `.feature` file
without it noticing. `scenario-commit` closes that at the commit, whatever
wrote the file, and turns the rule into the pairing review looks for: a
scenario moves only in a commit that also moves the spec.

Artefact concision, linking upstream, the owner field and scenario coverage are
deliberately *not* hooks. None has a test a script can run without guessing at
intent, and a gate that guesses is a gate that gets switched off.

## `.claude/sdlc.json`

| Key | Meaning |
| --- | --- |
| `version` | `2`. `init --hooks` upgrades a version 1 file in place. |
| `artifactDir` | Where change directories live. Default `docs/sdlc`. |
| `artifactPaths` | Globs `plan-sync` never requires a plan entry for. Must include the facts document, `CLAUDE.md`, `REVIEW.md` and `.github/copilot-instructions.md`, which are artefacts living outside the artefact directory. |
| `scenarioGlobs` | What the two scenario hooks protect. |
| `facts` | The facts document. Default `docs/estate.md`. |
| `verify` | The `build`, `test`, `lint` and `scenarios` commands, written by `/sdlc-loop:verify`. `null` means no such check; `scenarios: null` means no runner and the `.feature` files are the checklist the verifier reads by hand. |
| `deploy` | `"pr"` opens a pull request and runs the review loop; `"manual"` only prints how the change lands. |
| `gate` | Absent unless `init --gate` ran. Holds `approver` and `deployPatterns`. |
| `watch` | Absent unless `init --watch` ran. |

Globs take `*`, `?` and `**`. Brace expansion is not supported. `deployPatterns`
are shell globs matched against a command line, so `*` crosses `/` there.

## Reflect

The loop changes by evidence, not by chat. A correction that repeats is recorded
once in `<artifactDir>/PROPOSALS.md`. `/sdlc-loop:reflect` reads that inbox, the
change directories and the git history, asks the owner for their own notes, and
produces a change list with each item routed: to the plugin, for the next
version; to the project, applied now; or dropped, with the reason. Plugin-bound
items stay in the inbox with their route, so the plugin's own reflect run can
pick them up. Nothing is ever deleted from that file.

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
installing a detector with no stable baseline. A repo with no CI skips this
stage and says so in its `CLAUDE.md`.

Stage 6 is the one part of this plugin copied into the project — GitHub Actions
cannot see your plugin cache. Re-run `/sdlc-loop:watch` after upgrading.

## Tests

```bash
bash tests/run.sh
```

A scratch git repo per case, no network and no `gh`. Every hook is exercised both
blocking and staying silent, and every detection rule in isolation.

## Requirements

`bash` and `jq` for the hooks. `python3` (stdlib only) and `gh` for the watcher
and the deploy stage. Copilot code review on the GitHub account for the review
loop.
