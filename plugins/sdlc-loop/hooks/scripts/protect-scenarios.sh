#!/usr/bin/env bash
# protect-scenarios — the agent cannot rewrite the contract it is measured
# against.
#
# Blocks MODIFICATION of a .feature file, and allows CREATION. The spec's "block
# always" cannot be implemented literally: the escape route it names,
# /sdlc-loop:spec, has to write .feature files itself, so an unconditional block
# closes the door it points at. Creating a new scenario is the spec transition
# doing its job (R10); changing one that exists is the contract moving.
#
# Step definitions, unit tests and fixtures are untouched by this hook — they
# follow the code and are expected to churn.
set -uo pipefail

SDLC_INPUT=$(cat)
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sdlc_load_config "${1:-}"

mapfile -t globs < <(sdlc_cfg_list scenarioGlobs)
[ "${#globs[@]}" -gt 0 ] \
  || sdlc_note "no scenarioGlobs in .claude/sdlc.json — scenarios unprotected."

tool=$(printf '%s' "$SDLC_INPUT" | jq -r '.tool_name // empty')
target=$(printf '%s' "$SDLC_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$target" ] || exit 0

rel=$(sdlc_relpath "$target") || exit 0
sdlc_matches_any "$rel" "${globs[@]}" || exit 0

# Creating a scenario that does not exist yet is the spec transition working.
if [ "$tool" = "Write" ] && [ ! -e "$target" ]; then
  exit 0
fi

sdlc_deny "Blocked: $rel is an existing scenario file.

Scenarios are the contract this change is measured against, and they belong to
the artefact's owner. They change at the spec transition and nowhere else — not
during a fix, not during a feature, not to match what the code turned out to do.

Routes through:
  - The contract is genuinely wrong, or the behaviour changed: run
    /sdlc-loop:spec. To replace a scenario there, \`git rm\` the file and write a
    fresh one — that leaves a visible delete+add in the diff for review.
  - You need new behaviour: it gets a new scenario at the spec transition.

Step definitions, unit tests and fixtures are yours to edit freely."
