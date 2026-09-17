<!-- sdlc-loop:begin -->
## SDLC loop

This repo runs the six-stage loop from the `sdlc-loop` plugin. Artefacts are
plain markdown in git, one directory per change under `<artifacts-dir>/`, with
`CURRENT` naming the active one.

| Stage | Command | Writes |
| --- | --- | --- |
| 1 Plan | `/sdlc-loop:intent` | `intent.md` |
| 2 Design | `/sdlc-loop:spec` | `spec.md`, `.feature` files, red bindings |
| 3 Build | `/sdlc-loop:plan`, then `/sdlc-loop:build` | `plan.md`, code |
| 4 Test | `/sdlc-loop:test` | nothing; a fix or a stop, then `Status: built` |
| 5 Deploy | `/sdlc-loop:deploy` | the pull request, fixes from its review |
| 6 Maintain | `/sdlc-loop:watch` | `bands.yaml`, the detector |

Read `<facts-doc>` before drafting anything: it holds the estate's real names,
the facts the code does not say, and how changes land. A correction that
repeats goes to `<artifacts-dir>/PROPOSALS.md`, and `/sdlc-loop:reflect` turns
that inbox into the next version of the loop.

Link upstream, never restate it. Write what is essential and stop. Size comes
from scope: one change is one capability, one or two `.feature` files. An
intent that needs more is split, not cut.

`.feature` files and the Then assertions in their bindings are the contract.
They change at the design transition and nowhere else; hooks block both an edit
and a commit that moves them without `spec.md`. Unit tests and binding glue are
implementation detail, yours to change freely.

The verify commands live under `verify` in `.claude/sdlc.json`. Build runs them
until green; nothing about them belongs in this file.
<!-- sdlc-loop:end -->
