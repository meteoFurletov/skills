<!-- sdlc-loop:begin -->
## SDLC loop

This repo runs the six-stage loop from the `sdlc-loop` plugin. Artefacts are
plain markdown in git, one directory per change under `<artifacts-dir>/`.

| Command | Stage | Writes |
| --- | --- | --- |
| `/sdlc-loop:intent` | 1 — what changes and why | `intent.md` |
| `/sdlc-loop:spec` | 2 — requirements and the contract | `spec.md` + `.feature` |
| `/sdlc-loop:plan` | 3 — approach and files that change | `plan.md` |
| — | 4 — Build, against the plan | code |
| `/sdlc-loop:review` | 5 — the compliance pass | findings |
| `/sdlc-loop:watch` | 6 — CI drift detection | `bands.yaml`, workflow |

Link upstream, never restate it. The spec points at the intent; the plan points
at both. Write what is essential and stop.

### Scenarios are the contract

`.feature` files are the executable spec. They change at the spec transition and
nowhere else — a hook blocks edits to an existing one. Unit tests are the
opposite: implementation detail, yours to add, change or delete freely, and
never evidence on their own that a scenario holds.

### Verifying your work

Run these before claiming a change works. `/sdlc-loop:verify` fills them in.

| What | Command | Healthy output |
| --- | --- | --- |
| Build | `<build command>` | `<the real last line>` |
| Test | `<test command>` | `<the real last line>` |
| Lint | `<lint command>` | `<the real last line>` |
| Scenarios | `<scenario command, or "none — the .feature files are the checklist">` | `<the real last line>` |
<!-- sdlc-loop:end -->
