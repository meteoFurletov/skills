---
name: sdlc-watch-writeback
description: Use when a Stage 6 CI drift detection has fired and the diagnosis must be written back as a draft intent.md — normally a headless `claude -p` run started by the sdlc-watch GitHub Actions workflow, whose prompt carries a band breach, a rolling baseline mean and sigma, and a daily failure-rate series. Covers what to investigate read-only (gh run view, git log across the window), how to tell a regression from flakiness, and the hard limit that the run emits one intent.md in the Stage 1 format and nothing else. Do NOT use to fix the fault it diagnoses.
---

# Stage 6 write-back

A deterministic detector matched a CI failure-rate excursion against
`bands.yaml` and escalated. You are the diagnosis step. The loop closes by
turning a metric drift back into a Stage 1 intent that a human owner picks up.

## What this run produces

One `intent.md` in the Stage 1 format, on stdout, and nothing else. No preamble,
no code fences, no commentary after it. The calling script writes the file; you
do not. It compares `git status` before and after, and reverts if anything else
moved — so a stray edit fails the run rather than landing quietly.

Never fix the thing you diagnosed. The output is a draft intent, not a patch. A
drift that looks trivially fixable still goes through the loop; that is the point
of having one.

## Investigating

Read-only, and the window in the prompt bounds what is worth reading:

- `gh run list --json conclusion,createdAt,workflowName,headSha` for the shape.
- `gh run view <id> --log-failed` for what actually broke.
- `git log` across the window, to see what landed when the rate moved.

Look for the change that coincides with the excursion. A rate that rose on one
day and stayed up usually has a commit under it. One that oscillates usually
means flakiness. Say which — the two lead to entirely different work, and
guessing between them wastes the owner's time more than admitting uncertainty.

## Writing it

Follow the intent template given in the prompt.

- `Author: sdlc-watch`. Leave `Owner:` as `<name>` for a human to claim; an
  invented owner is worse than an obvious blank.
- `Status: draft`. Nobody has accepted this.
- **Problem** carries the numbers from the prompt — the band, the rule tripped,
  the baseline mean and standard deviation, the recent series — plus what you
  found in the logs. Evidence, not adjectives.
- **Scenarios** in plain words, where the drift points at behaviour that should
  have been caught. Where it points at flakiness, infrastructure or anything
  changing no behaviour, write "No scenario changes. The existing scenarios must
  still pass." and leave it.
- **Open questions** is where uncertainty goes. A genuinely ambiguous diagnosis
  should say so rather than pick a story; the human reading this is better placed
  to resolve it than you are from the logs.
