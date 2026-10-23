#!/bin/bash
# Renders the plugin against fixtures and checks the output. Usage: tests/run.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PLUGIN=./claude-usage.5m.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAILED=0

# Runs the plugin with a fixture in an isolated cache; extra args are env assignments.
render() {
  local fixture=$1; shift
  env CLAUDE_USAGE_FIXTURE="$fixture" CLAUDE_USAGE_CACHE_DIR="$TMP/cache" CLAUDE_USAGE_LANG=en "$@" "$PLUGIN" 2>"$TMP/stderr"
}
check() {
  local name=$1 expected=$2 actual=$3
  if grep -qF -- "$expected" <<<"$actual"; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected to find '$expected'"; printf '     %s\n' "$actual"; FAILED=1
  fi
}
check_absent() {
  local name=$1 unexpected=$2 actual=$3
  if grep -qF -- "$unexpected" <<<"$actual"; then echo "FAIL $name: found '$unexpected'"; FAILED=1; else echo "ok   $name"; fi
}
fresh() { rm -rf "$TMP/cache"; }
# Copy of a fixture with the session at $1 percent resetting $2 seconds from now.
session_at() {
  jq --argjson p "$1" --arg r "$(date -u -r $(( $(date +%s) + $2 )) +%Y-%m-%dT%H:%M:%S+00:00)" \
    '.limits |= map(if .kind == "session" then .percent = $p | .resets_at = $r else . end)' \
    fixtures/team-with-model-limit.json > "$TMP/session.json"
  echo "$TMP/session.json"
}

fresh; out=$(render fixtures/team-with-model-limit.json)
check "title shows session and weekly" "✳ 6% · 20%" "$out"
check "per-model weekly limit" "Weekly Fable  27%" "$out"
check "extra usage off" "Extra usage: off" "$out"

fresh; out=$(render fixtures/near-limit.json)
check "red title near the limit" "✳ 93% · 74% | color=#e5484d" "$out"
check "orange row at 74%" "Weekly (all models)  74% | font=Menlo size=12 href=https://claude.ai/settings/usage color=#f5a524" "$out"
check "extra usage on" "Extra usage: 12.5 / 50" "$out"

fresh; out=$(render fixtures/legacy-no-limits-array.json)
check "legacy response" "✳ 6% · 20%" "$out"

fresh; out=$(render fixtures/empty.json)
check "empty response" "✳ –" "$out"
check "empty message" "No limits to show" "$out"

fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_LANG=es)
check "spanish" "Sesión (5 h)  6%" "$out"

fresh; out=$(render fixtures/near-limit.json CLAUDE_USAGE_DISPLAY=session)
check "display=session" "✳ 93% | color" "$out"
fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_DISPLAY=max)
check "display=max" "✳ 27%" "$out"
fresh; out=$(render fixtures/near-limit.json CLAUDE_USAGE_DISPLAY=icon)
check "display=icon" "✳ ● | color" "$out"

fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_FAKE_LATEST=9.9.9)
check "update available" "Update available: v9.9.9" "$out"
check "update arrow in title" "✳ 6% · 20% ↑" "$out"
fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_FAKE_LATEST=0.1.0)
check_absent "no update for older release" "Update available" "$out"

# Reset notification: armed at >= 90%, fires once after the reset time.
fresh; out=$(render "$(session_at 95 3600)")
check "notification armed" "You'll be notified when the session resets" "$out"
check "warning sent when crossing the threshold" "NOTIFY: Claude: 95% of your session used - Resets at" "$(cat "$TMP/stderr")"
render "$(session_at 97 3590)" >/dev/null
check_absent "warning sent once per window" "NOTIFY" "$(cat "$TMP/stderr")"
render "$(session_at 92 9000)" >/dev/null
check "warning again in a new window" "NOTIFY: Claude: 92% of your session used" "$(cat "$TMP/stderr")"
fresh; render "$(session_at 95 3600)" CLAUDE_USAGE_LANG=es >/dev/null
check "spanish warning" "NOTIFY: Claude: llevas el 95 % de tu sesión - Se reinicia a las" "$(cat "$TMP/stderr")"
fresh; out=$(render "$(session_at 50 3600)")
check_absent "no warning below threshold" "NOTIFY" "$(cat "$TMP/stderr")"
check_absent "not armed below threshold" "notified" "$out"
fresh; out=$(render "$(session_at 95 3600)" CLAUDE_USAGE_NOTIFY_AT=0)
check_absent "disabled with NOTIFY_AT=0" "notified" "$out"
fresh; mkdir -p "$TMP/cache"; echo $(( $(date +%s) - 1 )) > "$TMP/cache/notify-at"
render "$(session_at 3 18000)" >/dev/null
check "notification fires after reset" "NOTIFY: Claude is available again" "$(cat "$TMP/stderr")"
render "$(session_at 3 18000)" >/dev/null
check_absent "notification fires only once" "NOTIFY" "$(cat "$TMP/stderr")"

exit $FAILED
