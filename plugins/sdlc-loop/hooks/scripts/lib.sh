# Shared machinery for the sdlc-loop hooks.
#
# Every hook is registered by the plugin in every session and is inert in any
# repo that has not opted in. Opting in is one file: .claude/sdlc.json.
#
# Two rules hold throughout:
#   - A hook that cannot establish its condition allows the action and says why.
#     Ambiguity never blocks.
#   - Nothing ever emits permissionDecision "allow". An explicit allow from a
#     PreToolUse hook bypasses the user's own permission settings; declining to
#     decide (exit 0) leaves those settings in force.

# Cannot establish the condition: say why, allow the action.
sdlc_note() {
  jq -n --arg m "sdlc-loop: $1" '{systemMessage: $m}'
  exit 0
}

sdlc_deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

sdlc_ask() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# The project root arrives as $1 from hooks.json via ${CLAUDE_PROJECT_DIR}.
# Hooks run in the session cwd, so the input's own `cwd` is not trustworthy and
# every git call must be `git -C "$SDLC_PROJ"`.
sdlc_load_config() {
  SDLC_PROJ=${1:-$PWD}
  SDLC_CFG="$SDLC_PROJ/.claude/sdlc.json"
  [ -f "$SDLC_CFG" ] || exit 0

  command -v jq >/dev/null 2>&1 || exit 0
  jq -e . "$SDLC_CFG" >/dev/null 2>&1 \
    || sdlc_note ".claude/sdlc.json is not valid JSON — no gate applied."
  SDLC_CONFIG=$(cat "$SDLC_CFG")
}

# Read a string array out of the config, one entry per line.
sdlc_cfg_list() {
  printf '%s' "$SDLC_CONFIG" | jq -r --arg k "$1" '(.[$k] // []) | .[]'
}

# Turn a shell glob into an anchored regex. `**/` spans directories, `*` and `?`
# stop at a separator, everything else is literal. Bash [[ ]] cannot do this:
# globstar only affects pathname expansion, so `features/**/*.feature` would
# never match `features/login.feature`.
sdlc_glob_to_regex() {
  printf '%s' "$1" | awk '
    {
      out = "^"; n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "*") {
          if (substr($0, i, 3) == "**/")     { out = out "(.*/)?"; i += 2 }
          else if (substr($0, i, 2) == "**") { out = out ".*";     i += 1 }
          else                               { out = out "[^/]*" }
        }
        else if (c == "?")                        { out = out "[^/]" }
        else if (index(".^$+(){}[]|\\", c) > 0)   { out = out "\\" c }
        else                                      { out = out c }
      }
      print out "$"
    }'
}

sdlc_matches_any() {
  local path=$1 glob
  shift
  for glob in "$@"; do
    [ -n "$glob" ] || continue
    printf '%s' "$path" | grep -Eq "$(sdlc_glob_to_regex "$glob")" && return 0
  done
  return 1
}

# Repo-relative, normalised. Returns 1 for a path outside the project.
sdlc_relpath() {
  local path=$1
  case $path in
    "$SDLC_PROJ"/*) path=${path#"$SDLC_PROJ"/} ;;
    /*)             return 1 ;;
  esac
  printf '%s' "${path#./}"
}
