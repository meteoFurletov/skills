#!/usr/bin/env bash
# plan-sync — when implementation departs from the plan, plan.md changes in the
# same commit.
#
# Departure is defined as the plan's own "Files that change" list being wrong,
# which is the only form of departure a script can see. A commit staying inside
# the planned file set passes untouched, so this is silent through a normal task.
set -uo pipefail

SDLC_INPUT=$(cat)
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sdlc_load_config "${1:-}"

# hooks.json also filters with `if`, but that is a registration-time convenience
# and its handling of compound commands is not something to rely on. The script
# is the authority.
cmd=$(printf '%s' "$SDLC_INPUT" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0
printf '%s' "$cmd" | grep -Eq '(^|[;&|]|&&)[[:space:]]*git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)' || exit 0

artifact_dir=$(printf '%s' "$SDLC_CONFIG" | jq -r '.artifactDir // empty')
[ -n "$artifact_dir" ] || sdlc_note "no artifactDir in .claude/sdlc.json."

# The active change, so "the current plan" is mechanical rather than a guess.
current_file="$SDLC_PROJ/$artifact_dir/CURRENT"
if [ -f "$current_file" ]; then
  current=$(head -n1 "$current_file" | tr -d '[:space:]')
  plan_rel="$artifact_dir/$current/plan.md"
else
  plan_rel="$artifact_dir/plan.md"
fi
plan="$SDLC_PROJ/$plan_rel"
[ -f "$plan" ] || sdlc_note "no $plan_rel to check this commit against."

staged=$(git -C "$SDLC_PROJ" diff --cached --name-only 2>/dev/null) \
  || sdlc_note "cannot read the git index."
[ -n "$staged" ] || exit 0

# "Files that change": the bullets between that heading and the next one.
planned=$(awk '
  /^#{1,6}[[:space:]]+Files that change[[:space:]]*$/ { inside = 1; next }
  inside && /^#{1,6}[[:space:]]/                      { inside = 0 }
  inside && /^[[:space:]]*[-*][[:space:]]+/ {
    sub(/^[[:space:]]*[-*][[:space:]]+/, "")
    gsub(/`/, "")
    sub(/[[:space:]]+—.*$/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 != "" && $0 !~ /^</) print
  }
' "$plan")
[ -n "$planned" ] \
  || sdlc_note "the Files that change list in $plan_rel is missing or empty."

mapfile -t artifact_paths < <(sdlc_cfg_list artifactPaths)
mapfile -t planned_arr <<< "$planned"

unplanned=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  # Artefacts are always allowed to move — CLAUDE.md and REVIEW.md live at the
  # repo root, so a single-directory rule would block every commit touching them.
  [ "${#artifact_paths[@]}" -gt 0 ] && sdlc_matches_any "$file" "${artifact_paths[@]}" && continue

  matched=0
  for entry in "${planned_arr[@]}"; do
    entry=${entry#./}; entry=${entry%/}
    [ -n "$entry" ] || continue
    [ "$file" = "$entry" ] && { matched=1; break; }
    case "$file" in "$entry"/*) matched=1; break ;; esac   # a directory covers its tree
    case "$entry" in *[*?]*) sdlc_matches_any "$file" "$entry" && { matched=1; break; } ;; esac
  done
  [ "$matched" -eq 1 ] || unplanned="$unplanned  $file"$'\n'
done <<< "$staged"

[ -n "$unplanned" ] || exit 0

# The plan moving with the code is exactly what this hook wants to see.
printf '%s' "$staged" | grep -qx "$plan_rel" && exit 0

sdlc_deny "Blocked: this commit departs from $plan_rel.

These staged files are not in its \"Files that change\" list:

$unplanned
Two ways through:
  1. The departure is right — add these paths to \"Files that change\" in
     $plan_rel and stage it with this commit.
  2. The departure is accidental — split these files out of this commit."
