#!/usr/bin/env bash
# deploy-gate — production releases wait for a named person.
#
# The only hook that pauses for a human, and it is out of the Build path by
# construction. `/sdlc-loop:init --gate` is the only thing that writes the "gate"
# key; without it this is inert even in an opted-in repo. It carries no `if`
# filter in hooks.json because its patterns are per-repo, so it fires on every
# Bash call and the opt-in check below is load-bearing.
set -uo pipefail

SDLC_INPUT=$(cat)
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sdlc_load_config "${1:-}"

printf '%s' "$SDLC_CONFIG" | jq -e '.gate' >/dev/null 2>&1 || exit 0

mapfile -t patterns < <(printf '%s' "$SDLC_CONFIG" | jq -r '(.gate.deployPatterns // []) | .[]')
[ "${#patterns[@]}" -gt 0 ] \
  || sdlc_note "a gate is configured with no deployPatterns — nothing to match."
approver=$(printf '%s' "$SDLC_CONFIG" | jq -r '.gate.approver // "the named approver"')
authorisation=$(printf '%s' "$SDLC_CONFIG" | jq -r '.gate.authorisation // empty')

cmd=$(printf '%s' "$SDLC_INPUT" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# Shell-style globbing, not the path matcher in lib.sh: `*` has to cross `/`
# here, because a deploy command is a command line and not a path.
for pattern in "${patterns[@]}"; do
  [ -n "$pattern" ] || continue
  # shellcheck disable=SC2254
  case "$cmd" in
    $pattern)
      msg="Deploy gate: this matches a production release pattern.

  Command:  $cmd
  Pattern:  $pattern
  Approver: $approver

No script can tell production from staging, so these patterns are the
definition of production in this repo. Production releases wait for a named
person: authorisation means $approver has seen this change and said to ship it."
      [ -n "$authorisation" ] && msg="$msg

What authorisation looks like here: $authorisation"
      sdlc_ask "$msg

If that has not happened, decline and ask them. To change what this gate
catches, edit \"gate\" in .claude/sdlc.json."
      ;;
  esac
done

exit 0
