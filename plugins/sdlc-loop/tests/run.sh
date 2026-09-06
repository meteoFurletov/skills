#!/usr/bin/env bash
# Hook and watcher tests. A scratch git repo per case, no network.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(dirname "$HERE")
SCRIPTS="$PLUGIN/hooks/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL  %s\n     expected %s, got %s\n' "$1" "$2" "$3"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

# --- glob matching ---------------------------------------------------------
echo "glob -> regex"
# shellcheck source=../hooks/scripts/lib.sh
. "$SCRIPTS/lib.sh"

g() { printf '%s' "$2" | grep -Eq "$(sdlc_glob_to_regex "$1")" && echo yes || echo no; }
check "features/**/*.feature matches a top-level file" yes "$(g 'features/**/*.feature' 'features/login.feature')"
check "features/**/*.feature matches a nested file"    yes "$(g 'features/**/*.feature' 'features/auth/login.feature')"
check "features/**/*.feature rejects another dir"      no  "$(g 'features/**/*.feature' 'src/login.feature')"
check "features/**/*.feature rejects another suffix"   no  "$(g 'features/**/*.feature' 'features/login.md')"
check "docs/sdlc/** matches nested"                    yes "$(g 'docs/sdlc/**' 'docs/sdlc/001-x/plan.md')"
check "* does not cross a separator"                   no  "$(g 'src/*.py' 'src/a/b.py')"
check "? matches one char"                             yes "$(g 'v?.txt' 'v1.txt')"
check "a dot is literal"                               no  "$(g 'a.txt' 'axtxt')"
check "CLAUDE.md matches itself"                       yes "$(g 'CLAUDE.md' 'CLAUDE.md')"

# --- fixture repo ----------------------------------------------------------
REPO="$TMP/repo"
mkdir -p "$REPO"/{.claude,features/auth,docs/sdlc/001-login,src}
git -C "$REPO" init -q .
git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
cp "$PLUGIN/templates/sdlc.json" "$REPO/.claude/sdlc.json"
printf 'Feature: login\n' > "$REPO/features/login.feature"
printf 'a\n' > "$REPO/src/app.py"; printf 'b\n' > "$REPO/src/rogue.py"
cat > "$REPO/docs/sdlc/001-login/plan.md" <<'PLAN'
# Plan: login

## Files that change

- `src/app.py`
- src/lib/

## Risks and rollback
PLAN
printf '001-login\n' > "$REPO/docs/sdlc/CURRENT"
mkdir -p "$REPO/src/lib"; printf 'c\n' > "$REPO/src/lib/x.py"

# Run a hook and report its decision, or "silent".
hook() {
  local script=$1 payload=$2 out
  out=$(printf '%s' "$payload" | bash "$SCRIPTS/$script" "$REPO" 2>/dev/null)
  [ -z "$out" ] && { echo silent; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "note"'
}

echo
echo "protect-scenarios"
check "modifying an existing .feature is denied" deny \
  "$(hook protect-scenarios.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/features/login.feature\"}}")"
check "overwriting an existing .feature is denied" deny \
  "$(hook protect-scenarios.sh "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO/features/login.feature\"}}")"
check "creating a new .feature is allowed" silent \
  "$(hook protect-scenarios.sh "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO/features/auth/signup.feature\"}}")"
check "editing a unit test is silent" silent \
  "$(hook protect-scenarios.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/src/app.py\"}}")"
mv "$REPO/.claude/sdlc.json" "$REPO/.claude/off.json"
check "no opt-in marker is silent" silent \
  "$(hook protect-scenarios.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/features/login.feature\"}}")"
mv "$REPO/.claude/off.json" "$REPO/.claude/sdlc.json"

echo
echo "plan-sync"
COMMIT='{"tool_name":"Bash","tool_input":{"command":"git commit -m wip"}}'
git -C "$REPO" add src/app.py src/lib/x.py
check "commit inside the planned set is silent" silent "$(hook plan-sync.sh "$COMMIT")"
check "a non-commit Bash call is silent" silent \
  "$(hook plan-sync.sh '{"tool_name":"Bash","tool_input":{"command":"git status"}}')"
git -C "$REPO" add src/rogue.py
check "an unplanned staged file is denied" deny "$(hook plan-sync.sh "$COMMIT")"
check "chained git commit is still caught" deny \
  "$(hook plan-sync.sh '{"tool_name":"Bash","tool_input":{"command":"git add -A && git commit -m wip"}}')"
cp "$PLUGIN/templates/CLAUDE.md" "$REPO/CLAUDE.md"; git -C "$REPO" add CLAUDE.md
check "an artifactPaths file needs no plan entry" deny "$(hook plan-sync.sh "$COMMIT")"
git -C "$REPO" reset -q src/rogue.py
check "only artefacts unplanned is silent" silent "$(hook plan-sync.sh "$COMMIT")"
git -C "$REPO" add src/rogue.py docs/sdlc/001-login/plan.md
check "plan.md staged alongside is silent" silent "$(hook plan-sync.sh "$COMMIT")"
mv "$REPO/docs/sdlc/001-login/plan.md" "$TMP/plan.bak"
check "no plan.md allows with a note" note "$(hook plan-sync.sh "$COMMIT")"
mv "$TMP/plan.bak" "$REPO/docs/sdlc/001-login/plan.md"

echo
echo "deploy-gate"
DEPLOY='{"tool_name":"Bash","tool_input":{"command":"kubectl apply -f k8s/prod.yaml"}}'
check "no gate configured is silent" silent "$(hook deploy-gate.sh "$DEPLOY")"
jq '. + {gate:{approver:"Nikita",deployPatterns:["kubectl apply*prod*","*deploy*production*"]}}' \
  "$REPO/.claude/sdlc.json" > "$TMP/g" && mv "$TMP/g" "$REPO/.claude/sdlc.json"
check "a matching deploy asks" ask "$(hook deploy-gate.sh "$DEPLOY")"
check "an unrelated command is silent" silent \
  "$(hook deploy-gate.sh '{"tool_name":"Bash","tool_input":{"command":"npm test"}}')"
check "a staging deploy is silent" silent \
  "$(hook deploy-gate.sh '{"tool_name":"Bash","tool_input":{"command":"kubectl apply -f k8s/staging.yaml"}}')"

echo
echo "watch.py"
WATCH="$PLUGIN/scripts/watch.py"
BANDS="$PLUGIN/templates/bands.yaml"
TODAY=2026-09-06

# Build a gh-shaped runs file from a list of daily failure rates, oldest first.
fixture() {
  python3 - "$1" > "$TMP/runs.json" <<'PYF'
import sys, json, datetime as dt
rates = [float(x) for x in sys.argv[1].split(",")]
end = dt.datetime(2026, 9, 6, 12, tzinfo=dt.timezone.utc)
runs, per_day = [], 100
for i, rate in enumerate(rates):
    when = (end - dt.timedelta(days=len(rates) - 1 - i)).isoformat().replace("+00:00", "Z")
    fails = round(rate * per_day)
    for k in range(per_day):
        runs.append({"conclusion": "failure" if k < fails else "success",
                     "createdAt": when, "workflowName": "ci"})
json.dump(runs, open(sys.argv[0] if False else "/dev/stdout", "w"))
PYF
}

act() {
  fixture "$1"
  python3 -B "$WATCH" --bands "$BANDS" --runs-from "$TMP/runs.json" \
    --today "$TODAY" --dry-run 2>&1 | sed -n 's/.*-> \([a-z_]*\).*/\1/p' | head -1
}
err() {
  fixture "$1"
  python3 -B "$WATCH" --bands "$BANDS" --runs-from "$TMP/runs.json" \
    --today "$TODAY" --dry-run 2>&1 >/dev/null | head -1
}

BASE="0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2"
check "a steady baseline finds nothing"       none        "$(act "$BASE,0.1")"
check "one point beyond 3 sigma proposes a PR" propose_pr "$(act "$BASE,0.9")"
check "2 of the last 3 beyond 2 sigma diagnoses" diagnose "$(act "$BASE,0.26,0.1,0.26")"
check "4 of the last 5 beyond 1 sigma logs"    log        "$(act "$BASE,0.2,0.2,0.1,0.2,0.2")"
check "8 consecutive above the mean logs"       log        "$(act "$BASE,0.15,0.15,0.15,0.15,0.15,0.15,0.15,0.15")"
check "a flat line finds nothing"              none        "$(act "$(python3 -c 'print(",".join(["0.0"]*31))')")"
check "short history refuses" "sdlc-watch: insufficient history: 10 calendar days spanned and 10 qualifying days, against 30 and 20 required. A baseline this short is noise, so no detection ran." \
  "$(err "0.1,0.2,0.1,0.1,0.2,0.1,0.1,0.2,0.1,0.1")"
check "no gh needed for any of the above"      none        "$(PATH=/usr/bin:/bin act "$BASE,0.1")"

echo
echo "bands.yaml reader"
check "restricted YAML parses" "watch|investigate|act" "$(python3 -B -c "
import importlib.util,sys
spec=importlib.util.spec_from_file_location('w','$WATCH');w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
print('|'.join(b['name'] for b in w.load_bands('$BANDS')['bands']))")"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
