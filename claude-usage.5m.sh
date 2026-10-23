#!/bin/bash
# <xbar.title>AI Usage Meter (Claude + Codex)</xbar.title>
# <xbar.version>v1.5.1</xbar.version>
# <xbar.author>Cristopher Huaroc</xbar.author>
# <xbar.desc>Shows your Claude and Codex plan usage (5-hour and weekly limits) in the menu bar.</xbar.desc>
# <xbar.dependencies>bash,jq,curl,Claude Code or Codex</xbar.dependencies>
# <xbar.abouturl>https://github.com/Cristopheer96/ai-usage-meter</xbar.abouturl>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.environment>[USAGE_PROVIDERS=auto, CLAUDE_USAGE_LANG=auto, CLAUDE_USAGE_DISPLAY=both, CLAUDE_USAGE_NOTIFY_AT=90]</swiftbar.environment>

# Unofficial. Claude: the endpoint Claude Code's /usage command uses. Codex: the rate limits
# Codex writes to its local session logs. Either may change without notice.
# The installer puts jq in Application Support when neither macOS nor Homebrew provides it.
export PATH="$HOME/Library/Application Support/AI Usage Meter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
VERSION="1.5.1"
REPO="Cristopheer96/ai-usage-meter"
CLAUDE_URL="https://claude.ai/settings/usage"
CODEX_URL="https://chatgpt.com/codex/settings/usage"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CACHE_DIR="${CLAUDE_USAGE_CACHE_DIR:-$HOME/Library/Caches/claude-usage-swiftbar}"
mkdir -p "$CACHE_DIR"
# Menu bar icons (@2x template PNGs rendered from icons/*.svg).
ICON_CLAUDE="iVBORw0KGgoAAAANSUhEUgAAACgAAAAaCAYAAADFTB7LAAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAACigAwAEAAAAAQAAABoAAAAAc4o16wAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAJBJREFUWAntlVEKwCAMQ3X3v/OGHwGpmbSopUj31xpd+sxYKcGfOvH3TtZOLFEvz4k37TwzDa7SvI5gCzINs5KUef91BJWg9smS4CpLBN77r6H1XfOKtaj+dOEJIoNsAO9cUi/hCaZBlh1LLzxBGkwxYf+xQI8earFlKKUedRNOzwhPMA0Ol21shCdonMdf/gFlMgcxGtCVmQAAAABJRU5ErkJggg=="
ICON_CODEX="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAACSgAwAEAAAAAQAAACQAAAAA+INbXQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAABJ5JREFUWAntlVmMnmMUx8cU3ahlKkWThrlpJ1qtNJoIjaUpVeGCIra4KcqIxhIJqcQSsWtRCRe9IEJLlFGCC1Rt0Vi62IUOGVQxlUirrRa/3/Q9k+Pt+803nbau+k9+33ve85xnec/znOdraNitnZ+BJoZshcXQAevha1gAp8Ie8L9pGjP9Av/0wFLaDoc+aXu+5lpmuLeY5Que82AxdIILmAozYBCsgZtgCPSDdngLfoSdotMYZQuYmXugP1RpMs6/oCqD9m+DFtghNdL7M3CSR2qMtB9+F7oRYjErsJ+FJ2El/A22rYNzoU8aSi9T70Buzb6Q5WKnw88QC1mEfTSUNR7HG2CcWXSLe61hRM6DzRATzS31nsj7R6n9U+yTSzHl171wmDHHXA1mtq7GEvEDxEJiUVeknh7uaDdzV8GeqV1zAowo+XwdCKvA/hZKjzqEVivEYO+WSfBq8X42z5BbZNofhqZwFs+RPF8Ex9gAd8A+kHUZL7Z/mJ1VtlVg4EqIiaoW5KLnQJbpvw82ge1vg2OJGb8I4pppLvzGDoBKjcNrZ7dodIqoWpCXo1WlvGcuBbPmBLNhf1BnwjcQC3sX2wM/OPkOxK7UbXjtuLDU2tOCjif246Kffd3mEyDLDNwAf4AxW2B+sgdhV2oRXju0llprLcgsGe+tPRVOgbivnsE+DLIO5eUxiPvIvsbXlFe7QeVLq9aC1hJ7NVjKISvNivsN1sOtUM7AMfjawbk8a8OhUpEhB8yqtaC7clDJdvvdGs/j93AexIHG7CqYyOYLOkKNYfBcVtiTkk/zz+K9JfkdPE+QmrrN37HGg4fay3AJjAJlBs8HF3w6HAnbaCwe0+j9Mia1Osg7YNubYDX+CndDLZkhJw3NwrD/6+Eonq8U/lvCnzO0HKfp8xw8BVGOHtrj4AJohg/Asq6XIUK65RiqfEG+vNXdcFTx3OZhJXif+DWWsAcwywPq13hg3ZLrYG8IecBnQifkDE3j3TGXQtaFvETms/8/9idFkIGW6OPgQrP8j1oAtn8FnoMpEAfVj+rNgqxS53keKmUGrA6DngYn1PZSuxEGQNZEXtwOY8RtPxHKZ6hWhtqKfjfzrNQBeGNwz9IEeC/5vsV2cOU5uh82gZfkDOgHqjcLGkecH+9Hj4FK9cfrBC5qRBHh4XWvOyAWa9WtAWNngx+SdScvPW3ZQbSvAMeruV20dckqMvCSra/dv4Ox/HIPtO1WyCjIsjIfAq8Or4ZQ3rKTcH4OjvETDIMedQ2tBn8JAysih+PzHzvL7b0SzIp95QEITcfQ50Kj/TvsFqirIUS4cjs+AXEuMCs1GW+uzOW8m4UssxYL2YA9F5pyQD17CgHxNa9hj67o4M3eBjGRB/tyKH+AW726iLNS/eA+6Rx6rYOYcBm2d9J8iANpmwd7DpQPNq4uPcivce3g1u6QPLTPwWaIheWnWSxvD64umanbwXhL+wyoK0u6NzqYIC/BZnBxXpRONhTWwqPwEnSAW3IstMIRoGaB8btUIxn9fcgZK9udtF+8S1dRGryR97PAvxnLeCNY+kvgetiuSiJ+t+pm4F/gtHOD43hfjgAAAABJRU5ErkJggg=="

# Language: CLAUDE_USAGE_LANG=en|es, or "auto" to follow the macOS language.
LANG_CODE="${CLAUDE_USAGE_LANG:-auto}"
if [ "$LANG_CODE" = "auto" ]; then
  LANG_CODE=$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2s/[^a-zA-Z]*\([a-zA-Z]*\).*/\1/p')
fi
case "$LANG_CODE" in
  es*)
    T_SESSION="Sesión (5 h)"; T_WEEKLY="Semanal (todos los modelos)"; T_WEEKLY_MODEL="Semanal"
    T_RESETS="reinicia en"; T_DAY="d"; T_EXTRA="Créditos extra"; T_EXTRA_OFF="Créditos extra: desactivados"
    T_OPEN="Abrir uso en claude.ai"; T_OPEN_CODEX="Abrir uso de Codex"; T_REFRESH="Actualizar"
    T_NO_CREDS="No hay sesión de Claude Code ni datos de Codex"
    T_LOGIN="Instala Claude Code (claude) o Codex e inicia sesión"; T_ERROR="Error al consultar el uso"
    T_EXPIRED="Token vencido: abre Claude Code para renovarlo"; T_NO_DATA="Sin límites que mostrar"
    T_STALE="Datos de las"; T_RATE_LIMITED="Demasiadas consultas: se reintentará en unos minutos"
    T_CODEX_FROM="Según tu último uso de Codex:"; T_CODEX_PLAN="Plan de Codex"
    T_RESET_TITLE="%s está disponible"; T_RESET_BODY="Tu límite de sesión de 5 horas se reinició."
    T_NOTIFY_ARMED="Te aviso cuando se reinicie la sesión"
    T_WARN_TITLE="%s: llevas el %s %% de tu sesión"; T_WARN_BODY="Se reinicia a las %s (en %s)."
    T_UPDATE="Nueva versión disponible"; T_UPDATE_INSTALL="Instalar actualización"; T_RELEASE_NOTES="Ver novedades" ;;
  *)
    T_SESSION="Session (5 h)"; T_WEEKLY="Weekly (all models)"; T_WEEKLY_MODEL="Weekly"
    T_RESETS="resets in"; T_DAY="d"; T_EXTRA="Extra usage"; T_EXTRA_OFF="Extra usage: off"
    T_OPEN="Open usage on claude.ai"; T_OPEN_CODEX="Open Codex usage"; T_REFRESH="Refresh"
    T_NO_CREDS="No Claude Code login or Codex data found"
    T_LOGIN="Install Claude Code (claude) or Codex and sign in"; T_ERROR="Could not fetch usage"
    T_EXPIRED="Token expired: open Claude Code to refresh it"; T_NO_DATA="No limits to show"
    T_STALE="Data from"; T_RATE_LIMITED="Too many requests: will retry in a few minutes"
    T_CODEX_FROM="As of your last Codex use:"; T_CODEX_PLAN="Codex plan"
    T_RESET_TITLE="%s is available again"; T_RESET_BODY="Your 5-hour session limit just reset."
    T_NOTIFY_ARMED="You'll be notified when the session resets"
    T_WARN_TITLE="%s: %s%% of your session used"; T_WARN_BODY="Resets at %s (in %s)."
    T_UPDATE="Update available"; T_UPDATE_INSTALL="Install update"; T_RELEASE_NOTES="What's new" ;;
esac

# Notifications go through the bundled notifier app (own icon); osascript is the fallback.
# In fixture mode they are printed to stderr instead.
NOTIFIER_APP="$HOME/Applications/AI Usage Meter.app"
notify() {
  if [ -n "$CLAUDE_USAGE_FIXTURE$CODEX_USAGE_FIXTURE" ]; then
    echo "NOTIFY: $1 - $2" >&2
  elif [ -d "$NOTIFIER_APP" ]; then
    mkdir -p "$CACHE_DIR/notifications"
    printf '%s\n%s\n' "$1" "$2" > "$CACHE_DIR/notifications/$(date +%s)-$$-$RANDOM.txt"
    open -n -g "$NOTIFIER_APP"
  else
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" >/dev/null 2>&1
  fi
}
provider_name() { if [ "$1" = "codex" ]; then echo "Codex"; else echo "Claude"; fi; }

# Which providers to show: USAGE_PROVIDERS=auto | claude | codex | both. With auto, the file
# name decides: claude-usage.*.sh and codex-usage.*.sh are two menu bar items.
PROVIDERS="${USAGE_PROVIDERS:-auto}"
if [ "$PROVIDERS" = "auto" ]; then
  case "$(basename "$0")" in
    codex-usage*) PROVIDERS=codex ;;
    claude-usage*) PROVIDERS=claude ;;
  esac
fi
has_claude() { [ -n "$CLAUDE_USAGE_FIXTURE" ] || { [ -z "$CODEX_USAGE_FIXTURE" ] && security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; }; }
has_codex() { [ -n "$CODEX_USAGE_FIXTURE" ] || { [ -z "$CLAUDE_USAGE_FIXTURE" ] && [ -d "$CODEX_DIR/sessions" ]; }; }
want() {
  case "$PROVIDERS" in
    both) return 0 ;;
    auto) "has_$1" ;;
    *) [ "$PROVIDERS" = "$1" ] ;;
  esac
}

# Session reset notifications: fire once when a reset we were waiting for has passed.
for ID in claude codex; do
  want "$ID" || continue
  NOTIFY_FILE="$CACHE_DIR/notify-at-$ID"
  if [ -f "$NOTIFY_FILE" ] && [ "$(date +%s)" -ge "$(cat "$NOTIFY_FILE")" ]; then
    rm -f "$NOTIFY_FILE"
    # shellcheck disable=SC2059
    notify "$(printf "$T_RESET_TITLE" "$(provider_name "$ID")")" "$T_RESET_BODY"
  fi
done

# Claude: prints a provider object, or one with "error" lines.
claude_provider() {
  local body code note="" cache="$CACHE_DIR/last.json" cooldown="$CACHE_DIR/retry-until"
  if [ -n "$CLAUDE_USAGE_FIXTURE" ]; then
    body=$(cat "$CLAUDE_USAGE_FIXTURE"); code=200
  else
    local token
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -z "$token" ]; then
      jq -n --arg e "$T_NO_CREDS" '{id: "claude", name: "Claude", symbol: "✳", error: [$e], limits: []}'; return
    fi
    # The endpoint rate-limits (429 + retry-after); skip calls during the cooldown.
    if [ -f "$cooldown" ] && [ "$(date +%s)" -lt "$(cat "$cooldown")" ]; then
      code="429"
    else
      local headers response retry
      headers=$(mktemp)
      response=$(curl -s -m 10 -D "$headers" -w '\n%{http_code}' https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20")
      code=$(tail -n1 <<<"$response"); body=$(sed '$d' <<<"$response")
      retry=$(awk 'tolower($1) == "retry-after:" { print $2 + 0 }' "$headers"); rm -f "$headers"
      if [ "$code" = "200" ]; then
        printf '%s' "$body" > "$cache"; rm -f "$cooldown"
      elif [ "$code" = "429" ]; then
        # retry-after is sometimes 0 while still limited; wait at least 5 min.
        retry=${retry:-300}; [ "$retry" -lt 300 ] && retry=300
        echo $(( $(date +%s) + retry )) > "$cooldown"
      fi
    fi
    if [ "$code" != "200" ]; then
      if [ -s "$cache" ] && [ "$code" != "401" ]; then
        body=$(cat "$cache"); note="⚠ $T_STALE $(stat -f %Sm -t %H:%M "$cache") ($code)"
      else
        local hint=""
        [ "$code" = "401" ] && hint="$T_EXPIRED"
        [ "$code" = "429" ] && hint="$T_RATE_LIMITED"
        jq -n --arg e "$T_ERROR ($code)" --arg h "$hint" \
          '{id: "claude", name: "Claude", symbol: "✳", error: ([$e, $h] | map(select(. != ""))), limits: []}'
        return
      fi
    fi
  fi
  jq -c --arg note "$note" --arg session "$T_SESSION" --arg weekly "$T_WEEKLY" --arg weeklyModel "$T_WEEKLY_MODEL" \
    --arg extra "$T_EXTRA" --arg extraOff "$T_EXTRA_OFF" '
    def epoch: if . == null then null else sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch null end;
    # Older responses only have five_hour / seven_day.
    (.limits // ([
        (.five_hour | select(. != null) | {kind: "session", percent: (.utilization | floor), resets_at}),
        (.seven_day | select(. != null) | {kind: "weekly_all", percent: (.utilization | floor), resets_at})
      ])) as $limits
    | {id: "claude", name: "Claude", symbol: "✳", note: $note,
       limits: [$limits[] | {kind, percent, resets_at: (.resets_at | epoch),
         label: (if .kind == "session" then $session elif .kind == "weekly_all" then $weekly
                 else "\($weeklyModel) \(.scope.model.display_name // .scope.surface // .kind)" end)}],
       extra: (.extra_usage // {} | if .is_enabled then "\($extra): \(.used_credits // 0) / \(.monthly_limit // "∞")" else $extraOff end)}
  ' <<<"$body"
}

# Codex: latest rate limits from its session logs (updated whenever you use Codex).
codex_provider() {
  local events
  if [ -n "$CODEX_USAGE_FIXTURE" ]; then
    events=$(grep -h '"rate_limits"' "$CODEX_USAGE_FIXTURE")
  else
    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(find "$CODEX_DIR/sessions" -name '*.jsonl' -mtime -8 -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)
    [ ${#files[@]} -gt 0 ] && events=$(grep -h '"rate_limits"' "${files[@]}" 2>/dev/null)
  fi
  jq -cs --arg session "$T_SESSION" --arg weekly "$T_WEEKLY_MODEL" --arg from "$T_CODEX_FROM" \
    --arg plan "$T_CODEX_PLAN" '
    def window: if . == 300 then $session elif . == 10080 then $weekly else "\(. / 60 | floor) h" end;
    # A window whose reset already passed is back at 0%.
    def limit(kind): select(. != null) | {kind: kind, label: (.window_minutes | window),
      percent: (if (.resets_at // 0) < now then 0 else (.used_percent | floor) end), resets_at};
    map(select(.payload.rate_limits.limit_id == "codex" or .payload.rate_limits.limit_id == null))
    | sort_by(.timestamp) | last
    | if . == null then {id: "codex", name: "Codex", symbol: "⬡", limits: []}
      else (.timestamp | sub("\\.[0-9]+"; "") | fromdateiso8601) as $at
      | .payload.rate_limits as $r
      | {id: "codex", name: "Codex", symbol: "⬡",
         note: (if now - $at > 600 then "🕘 \($from) \($at | localtime | strftime(if ($at | localtime | strftime("%F")) == (now | localtime | strftime("%F")) then "%H:%M" else "%d/%m %H:%M" end))" else "" end),
         limits: [($r.primary | limit(if .window_minutes == 300 then "session" else "primary" end)),
                  ($r.secondary | limit(if .window_minutes == 10080 then "weekly_all" else "secondary" end))],
         extra: (if $r.plan_type then "\($plan): \($r.plan_type)" else null end)}
      end
  ' <<<"${events:-}"
}

PROVIDER_JSON=""
want claude && PROVIDER_JSON+=$(claude_provider)
want codex && PROVIDER_JSON+=$(codex_provider)
if [ -z "$PROVIDER_JSON" ]; then
  echo "✳ ? | color=gray"; echo "---"; echo "$T_NO_CREDS"; echo "$T_LOGIN"; exit 0
fi
PROVIDER_JSON=$(jq -cs . <<<"$PROVIDER_JSON")

# At CLAUDE_USAGE_NOTIFY_AT (0 disables it): warn once per session window and arm the reset notification.
NOTIFY_AT="${CLAUDE_USAGE_NOTIFY_AT:-90}"
ARMED=""
while read -r ID PCT RESET; do
  [ -z "$ID" ] && continue
  NOTIFY_FILE="$CACHE_DIR/notify-at-$ID"
  if [ "$NOTIFY_AT" -gt 0 ] 2>/dev/null && [ "$PCT" -ge "$NOTIFY_AT" ] && [ "$RESET" -gt "$(date +%s)" ]; then
    echo "$RESET" > "$NOTIFY_FILE"
    WARNED_FILE="$CACHE_DIR/warned-for-$ID"
    WARNED=$(cat "$WARNED_FILE" 2>/dev/null || echo 0)
    # resets_at can drift a few seconds between responses; same window if within 5 min.
    if [ $(( RESET - WARNED )) -gt 300 ] || [ $(( WARNED - RESET )) -gt 300 ]; then
      echo "$RESET" > "$WARNED_FILE"
      MINS=$(( (RESET - $(date +%s)) / 60 ))
      if [ "$MINS" -lt 60 ]; then IN="$MINS min"; else IN="$(( MINS / 60 )) h $(( MINS % 60 )) min"; fi
      # shellcheck disable=SC2059
      notify "$(printf "$T_WARN_TITLE" "$(provider_name "$ID")" "$PCT")" "$(printf "$T_WARN_BODY" "$(date -r "$RESET" +%H:%M)" "$IN")"
    fi
  fi
  [ -f "$NOTIFY_FILE" ] && ARMED+=" $ID"
done < <(jq -r '.[] | .id as $id | .limits[] | select(.kind == "session" and .resets_at != null) | "\($id) \(.percent) \(.resets_at | floor)"' <<<"$PROVIDER_JSON")

# Update check: at most once a day, against the latest GitHub release.
LATEST=""
if [ -z "$CLAUDE_USAGE_FIXTURE$CODEX_USAGE_FIXTURE" ]; then
  LATEST_FILE="$CACHE_DIR/latest-version"
  if [ ! -f "$LATEST_FILE" ] || [ -n "$(find "$LATEST_FILE" -mtime +0 2>/dev/null)" ]; then
    TAG=$(curl -sL -m 5 "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name // empty' 2>/dev/null)
    if [ -n "$TAG" ]; then echo "${TAG#v}" > "$LATEST_FILE"; else touch "$LATEST_FILE"; fi
  fi
  LATEST=$(cat "$LATEST_FILE" 2>/dev/null)
else
  LATEST="${CLAUDE_USAGE_FAKE_LATEST:-}"
fi
if [ -n "$LATEST" ] && [ "$LATEST" != "$VERSION" ] \
   && [ "$(printf '%s\n%s\n' "$VERSION" "$LATEST" | sort -V | tail -1)" = "$LATEST" ]; then
  UPDATE="$LATEST"
fi

jq -r \
  --arg resets "$T_RESETS" --arg day "$T_DAY" --arg noData "$T_NO_DATA" \
  --arg open "$T_OPEN" --arg openCodex "$T_OPEN_CODEX" --arg refresh "$T_REFRESH" \
  --arg claudeUrl "$CLAUDE_URL" --arg codexUrl "$CODEX_URL" \
  --arg armedIds "$ARMED" --arg armed "$T_NOTIFY_ARMED" --arg display "${CLAUDE_USAGE_DISPLAY:-both}" \
  --arg update "${UPDATE:-}" --arg updateLabel "$T_UPDATE" --arg updateInstall "$T_UPDATE_INSTALL" \
  --arg releaseNotes "$T_RELEASE_NOTES" --arg repo "$REPO" \
  --arg iconClaude "$ICON_CLAUDE" --arg iconCodex "$ICON_CODEX" '
  def left: if . == null then "" else . - now
      | if . < 0 then ""
        elif . < 3600 then "\(. / 60 | floor) min"
        elif . < 86400 then "\(. / 3600 | floor) h \((. % 3600) / 60 | floor) min"
        else "\(. / 86400 | floor) \($day) \((. % 86400) / 3600 | floor) h" end
      | if . == "" then "" else "  \($resets) \(.)" end end;
  def color(p): if p >= 90 then "#e5484d" elif p >= 70 then "#f5a524" else null end;
  def bar(p): (p / 10 | floor | if . > 10 then 10 elif . < 0 then 0 else . end) as $n
    | ([range(0; $n)] | map("█") | join("")) + ([range(0; 10 - $n)] | map("░") | join(""));
  def pie(p): if p < 12.5 then "○" elif p < 37.5 then "◔" elif p < 62.5 then "◑" elif p < 87.5 then "◕" else "●" end;
  def url: if .id == "codex" then $codexUrl else $claudeUrl end;
  def opts(p; u): " href=\(u)" + (if color(p) then " color=\(color(p))" else "" end);
  # CLAUDE_USAGE_DISPLAY: both | session | max | icon
  # $p is the symbol prefix; a single provider shows its icon image instead.
  def title($p):
    ([.limits[] | select(.kind == "session") | .percent] | first) as $s
    | ([.limits[] | select(.kind == "weekly_all") | .percent] | first) as $w
    | ([.limits[].percent] | max // 0) as $top
    | if .error then "\($p)⚠"
      elif .limits == [] then "\($p)–"
      elif $display == "session" and $s != null then "\($p)\($s)%"
      elif $display == "max" then "\($p)\($top)%"
      elif $display == "icon" then "\($p)\(pie($top))"
      elif $s != null and $w != null then "\($p)\($s)% · \($w)%"
      else "\($p)\($top)%" end;

  . as $providers
  | ($providers | length > 1) as $multi
  | ([$providers[].limits[].percent] | max // 0) as $top
  | (if $multi then ($providers | map(title("\(.symbol) ")) | join("  ")) else ($providers[0] | title("")) end)
    + (if $update != "" then " ↑" else "" end)
    + ([(if $multi then empty else "templateImage=\(if $providers[0].id == "codex" then $iconCodex else $iconClaude end)" end),
        (if color($top) then "color=\(color($top))" elif any($providers[]; .error) then "color=orange" else empty end)]
       | if length > 0 then " | " + join(" ") else "" end),
    "---",
    (if $update != "" then
       "⬆ \($updateLabel): v\($update) | color=#3b82f6",
       "\($updateInstall) | bash=/bin/bash param1=-c param2=\"bash <(curl -fsSL https://raw.githubusercontent.com/\($repo)/main/install.sh)\" terminal=false refresh=true",
       "\($releaseNotes) | href=https://github.com/\($repo)/releases/latest",
       "---"
     else empty end),
    ($providers | to_entries[] | .key as $i | .value | url as $u
      | (if $multi then (if $i > 0 then "---" else empty end), "\(.name) | size=13" else empty end),
        (if (.note // "") != "" then "\(.note) | color=gray", (if $multi then empty else "---" end) else empty end),
        (.error // [] | .[] | "\(.) | color=orange"),
        (if .limits == [] and (.error | not) then $noData else empty end),
        (.limits[] | "\(.label)  \(.percent)% | font=Menlo size=12" + opts(.percent; $u),
                     "\(bar(.percent))\(.resets_at | left) | font=Menlo size=11 href=\($u)"),
        (.id as $pid | if ($armedIds | split(" ") | index($pid)) then "🔔 \($armed) | color=gray size=11" else empty end)),
    "---",
    ([$providers[] | .extra // empty] | if length > 0 then (.[], "---") else empty end),
    ($providers[] | if .id == "codex" then "\($openCodex) | href=\($codexUrl)" else "\($open) | href=\($claudeUrl)" end),
    "\($refresh) | refresh=true"
' <<<"$PROVIDER_JSON"
