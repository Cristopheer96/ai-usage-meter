#!/bin/bash
# Renders the plugin against fixtures and checks the output. Usage: tests/run.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PLUGIN=./claude-usage.5m.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# Installed as two files; the name picks the provider.
cp "$PLUGIN" "$TMP/codex-usage.5m.sh"
FAILED=0

# Runs the plugin with a fixture in an isolated cache; extra args are env assignments.
render() {
  local fixture=$1; shift
  env CLAUDE_USAGE_FIXTURE="$fixture" CODEX_USAGE_FIXTURE="" CLAUDE_USAGE_CACHE_DIR="$TMP/cache" CLAUDE_USAGE_LANG=en "$@" "$PLUGIN" 2>"$TMP/stderr"
}
# Same, as the codex-usage plugin file.
render_codex() {
  env CLAUDE_USAGE_FIXTURE="" CODEX_USAGE_FIXTURE="$1" CLAUDE_USAGE_CACHE_DIR="$TMP/cache" CLAUDE_USAGE_LANG=en "${@:2}" "$TMP/codex-usage.5m.sh" 2>"$TMP/stderr"
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
check "title shows session and weekly" "6% · 20% | templateImage=" "$out"
check_absent "no symbol with a single provider" "✳" "$out"
check "per-model weekly limit" "Weekly Fable  27%" "$out"
check "extra usage off" "Extra usage: off" "$out"

fresh; out=$(render fixtures/near-limit.json)
check "red title near the limit" "93% · 74% | templateImage=" "$out"
check "red color near the limit" "color=#e5484d" "$out"
check "orange row at 74%" "Weekly (all models)  74% | font=Menlo size=12 href=https://claude.ai/settings/usage color=#f5a524" "$out"
check "extra usage on" "Extra usage: 12.5 / 50" "$out"

fresh; out=$(render fixtures/legacy-no-limits-array.json)
check "legacy response" "6% · 20% |" "$out"

fresh; out=$(render fixtures/empty.json)
check "empty response" "– | templateImage=" "$out"
check "empty message" "No limits to show" "$out"

fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_LANG=es)
check "spanish" "Sesión (5 h)  6%" "$out"

fresh; out=$(render fixtures/near-limit.json CLAUDE_USAGE_DISPLAY=session)
check "display=session" "93% | templateImage=" "$out"
fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_DISPLAY=max)
check "display=max" "27% | templateImage=" "$out"
fresh; out=$(render fixtures/near-limit.json CLAUDE_USAGE_DISPLAY=icon)
check "display=icon" "● | templateImage=" "$out"

fresh; out=$(render fixtures/team-with-model-limit.json CLAUDE_USAGE_FAKE_LATEST=9.9.9)
check "update available" "Update available: v9.9.9" "$out"
check "update arrow in title" "6% · 20% ↑ |" "$out"
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
fresh; mkdir -p "$TMP/cache"; echo $(( $(date +%s) - 1 )) > "$TMP/cache/notify-at-claude"
render "$(session_at 3 18000)" >/dev/null
check "notification fires after reset" "NOTIFY: Claude is available again" "$(cat "$TMP/stderr")"
render "$(session_at 3 18000)" >/dev/null
check_absent "notification fires only once" "NOTIFY" "$(cat "$TMP/stderr")"

# Codex: copy of the fixture with the 5-hour limit at $1 percent resetting $2 seconds from now.
codex_at() {
  jq -c --argjson p "$1" --argjson r "$(( $(date +%s) + $2 ))" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    'if .payload.rate_limits.limit_id == "codex" then .timestamp = $ts | .payload.rate_limits.primary.used_percent = $p
       | .payload.rate_limits.primary.resets_at = $r | .payload.rate_limits.secondary.resets_at = ($r + 400000) else . end' \
    fixtures/codex-session.jsonl > "$TMP/codex.jsonl"
  echo "$TMP/codex.jsonl"
}

fresh; out=$(render_codex fixtures/codex-session.jsonl)
check "codex only" "24% · 24% | templateImage=" "$out"
check_absent "codex ignores other limit ids" "99%" "$out"
check "codex old data note" "As of your last Codex use:" "$out"
check "codex plan" "Codex plan: plus" "$out"
check "codex link" "Open Codex usage | href=https://chatgpt.com/codex/settings/usage" "$out"
check_absent "codex only has no claude" "claude.ai" "$out"

fresh; out=$(render_codex "$(codex_at 40 3600)")
check "codex fresh data" "40% · 24% |" "$out"
check_absent "no note for fresh codex data" "As of your last" "$out"
check "codex reset time" "resets in 59 min" "$out"

fresh; out=$(render_codex "$(codex_at 40 -60)")
check "codex window already reset is 0%" "0% · 24% |" "$out"

fresh; printf '' > "$TMP/empty.jsonl"; out=$(render_codex "$TMP/empty.jsonl")
check "codex without data" "– | templateImage=" "$out"

fresh; out=$(render fixtures/team-with-model-limit.json CODEX_USAGE_FIXTURE=fixtures/codex-session.jsonl USAGE_PROVIDERS=both)
check_absent "no icon image when combined" "templateImage" "$out"
check "both providers in title" "✳ 6% · 20%  ⬡ 24% · 24%" "$out"
check "claude header" "Claude | size=13" "$out"
check "codex header" "Codex | size=13" "$out"
fresh; out=$(render fixtures/team-with-model-limit.json CODEX_USAGE_FIXTURE=fixtures/codex-session.jsonl USAGE_PROVIDERS=claude)
check_absent "USAGE_PROVIDERS=claude hides codex" "Codex" "$out"
fresh; out=$(render fixtures/team-with-model-limit.json CODEX_USAGE_FIXTURE=fixtures/codex-session.jsonl USAGE_PROVIDERS=codex)
check_absent "USAGE_PROVIDERS=codex hides claude" "Claude" "$out"
fresh; out=$(render fixtures/near-limit.json CODEX_USAGE_FIXTURE=fixtures/codex-session.jsonl CLAUDE_USAGE_DISPLAY=icon USAGE_PROVIDERS=both)
check "icon display per provider" "✳ ●  ⬡ ◔" "$out"

fresh; out=$(render_codex "$(codex_at 93 3600)")
check "codex warning" "NOTIFY: Codex: 93% of your session used" "$(cat "$TMP/stderr")"
check "codex armed" "You'll be notified when the session resets" "$out"
mkdir -p "$TMP/cache"; echo $(( $(date +%s) - 1 )) > "$TMP/cache/notify-at-codex"
render_codex "$(codex_at 5 18000)" >/dev/null
check "codex reset notification" "NOTIFY: Codex is available again" "$(cat "$TMP/stderr")"

exit $FAILED
