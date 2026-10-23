#!/bin/bash
# <xbar.title>Claude Usage</xbar.title>
# <xbar.version>v1.3.0</xbar.version>
# <xbar.author>Cristopher Huaroc</xbar.author>
# <xbar.desc>Shows your Claude plan usage (5-hour session and weekly limits) in the menu bar, using your Claude Code login.</xbar.desc>
# <xbar.dependencies>bash,jq,curl,Claude Code</xbar.dependencies>
# <xbar.abouturl>https://github.com/Cristopheer96/claude-usage-swiftbar</xbar.abouturl>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.environment>[CLAUDE_USAGE_LANG=auto, CLAUDE_USAGE_DISPLAY=both, CLAUDE_USAGE_NOTIFY_AT=90]</swiftbar.environment>

# Unofficial: reads the same endpoint Claude Code's /usage command uses. It may change without notice.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
VERSION="1.3.0"
REPO="Cristopheer96/claude-usage-swiftbar"
USAGE_URL="https://claude.ai/settings/usage"
CACHE_DIR="${CLAUDE_USAGE_CACHE_DIR:-$HOME/Library/Caches/claude-usage-swiftbar}"
mkdir -p "$CACHE_DIR"

# Language: CLAUDE_USAGE_LANG=en|es, or "auto" to follow the macOS language.
LANG_CODE="${CLAUDE_USAGE_LANG:-auto}"
if [ "$LANG_CODE" = "auto" ]; then
  LANG_CODE=$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2s/[^a-zA-Z]*\([a-zA-Z]*\).*/\1/p')
fi
case "$LANG_CODE" in
  es*)
    T_SESSION="Sesión (5 h)"; T_WEEKLY="Semanal (todos los modelos)"; T_WEEKLY_MODEL="Semanal"
    T_RESETS="reinicia en"; T_DAY="d"; T_EXTRA="Créditos extra"; T_EXTRA_OFF="Créditos extra: desactivados"
    T_OPEN="Abrir uso en claude.ai"; T_REFRESH="Actualizar"; T_NO_CREDS="No hay sesión de Claude Code en el Keychain"
    T_LOGIN="Instala Claude Code e inicia sesión con: claude"; T_ERROR="Error al consultar el uso"
    T_EXPIRED="Token vencido: abre Claude Code para renovarlo"; T_NO_DATA="Sin límites que mostrar"
    T_STALE="Datos de las"; T_RATE_LIMITED="Demasiadas consultas: se reintentará en unos minutos"
    T_RESET_TITLE="Claude está disponible"; T_RESET_BODY="Tu límite de sesión de 5 horas se reinició."
    T_NOTIFY_ARMED="Te aviso cuando se reinicie la sesión"
    T_WARN_TITLE="Claude: llevas el %s %% de tu sesión"; T_WARN_BODY="Se reinicia a las %s (en %s)."
    T_UPDATE="Nueva versión disponible"; T_UPDATE_INSTALL="Instalar actualización"; T_RELEASE_NOTES="Ver novedades" ;;
  *)
    T_SESSION="Session (5 h)"; T_WEEKLY="Weekly (all models)"; T_WEEKLY_MODEL="Weekly"
    T_RESETS="resets in"; T_DAY="d"; T_EXTRA="Extra usage"; T_EXTRA_OFF="Extra usage: off"
    T_OPEN="Open usage on claude.ai"; T_REFRESH="Refresh"; T_NO_CREDS="No Claude Code login found in Keychain"
    T_LOGIN="Install Claude Code and sign in with: claude"; T_ERROR="Could not fetch usage"
    T_EXPIRED="Token expired: open Claude Code to refresh it"; T_NO_DATA="No limits to show"
    T_STALE="Data from"; T_RATE_LIMITED="Too many requests: will retry in a few minutes"
    T_RESET_TITLE="Claude is available again"; T_RESET_BODY="Your 5-hour session limit just reset."
    T_NOTIFY_ARMED="You'll be notified when the session resets"
    T_WARN_TITLE="Claude: %s%% of your session used"; T_WARN_BODY="Resets at %s (in %s)."
    T_UPDATE="Update available"; T_UPDATE_INSTALL="Install update"; T_RELEASE_NOTES="What's new" ;;
esac

# In fixture mode notifications are printed to stderr instead of shown.
notify() {
  if [ -n "$CLAUDE_USAGE_FIXTURE" ]; then
    echo "NOTIFY: $1 - $2" >&2
  else
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" >/dev/null 2>&1
  fi
}

# Session reset notification: fires once when a reset we were waiting for has passed.
NOTIFY_FILE="$CACHE_DIR/notify-at"
if [ -f "$NOTIFY_FILE" ] && [ "$(date +%s)" -ge "$(cat "$NOTIFY_FILE")" ]; then
  rm -f "$NOTIFY_FILE"
  notify "$T_RESET_TITLE" "$T_RESET_BODY"
fi

# CLAUDE_USAGE_FIXTURE=path/to.json renders a saved response instead of calling the API (for testing).
if [ -n "$CLAUDE_USAGE_FIXTURE" ]; then
  BODY=$(cat "$CLAUDE_USAGE_FIXTURE")
else
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    echo "✳ ? | color=gray"; echo "---"; echo "$T_NO_CREDS"; echo "$T_LOGIN"; exit 0
  fi
  CACHE="$CACHE_DIR/last.json"; COOLDOWN="$CACHE_DIR/retry-until"
  # The endpoint rate-limits (429 + retry-after); skip calls during the cooldown.
  if [ -f "$COOLDOWN" ] && [ "$(date +%s)" -lt "$(cat "$COOLDOWN")" ]; then
    CODE="429"
  else
    HEADERS=$(mktemp)
    RESPONSE=$(curl -s -m 10 -D "$HEADERS" -w '\n%{http_code}' https://api.anthropic.com/api/oauth/usage \
      -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20")
    CODE=$(tail -n1 <<<"$RESPONSE"); BODY=$(sed '$d' <<<"$RESPONSE")
    RETRY=$(awk 'tolower($1) == "retry-after:" { print $2 + 0 }' "$HEADERS"); rm -f "$HEADERS"
    if [ "$CODE" = "200" ]; then
      printf '%s' "$BODY" > "$CACHE"; rm -f "$COOLDOWN"
    elif [ "$CODE" = "429" ]; then
      echo $(( $(date +%s) + ${RETRY:-300} )) > "$COOLDOWN"
    fi
  fi
  if [ "$CODE" != "200" ]; then
    if [ -s "$CACHE" ] && [ "$CODE" != "401" ]; then
      BODY=$(cat "$CACHE"); NOTE="$T_STALE $(stat -f %Sm -t %H:%M "$CACHE") ($CODE)"
    else
      echo "✳ ⚠ | color=orange"; echo "---"; echo "$T_ERROR ($CODE)"
      [ "$CODE" = "401" ] && echo "$T_EXPIRED"
      [ "$CODE" = "429" ] && echo "$T_RATE_LIMITED"
      echo "$T_REFRESH | refresh=true"; exit 0
    fi
  fi
fi

# At CLAUDE_USAGE_NOTIFY_AT (0 disables it): warn once per session window and arm the reset notification.
NOTIFY_AT="${CLAUDE_USAGE_NOTIFY_AT:-90}"
SESSION_STATE=$(jq -r '
  ((.limits // []) | map(select(.kind == "session")) | first // null) as $l
  | ($l // (.five_hour | if . then {percent: (.utilization | floor), resets_at} else null end))
  | if . then "\(.percent) \(.resets_at // "" | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch 0)" else "" end
' <<<"$BODY" 2>/dev/null)
read -r SESSION_PCT SESSION_RESET <<<"$SESSION_STATE"
if [ "$NOTIFY_AT" -gt 0 ] 2>/dev/null && [ -n "$SESSION_PCT" ] && [ "$SESSION_PCT" -ge "$NOTIFY_AT" ] \
   && [ "${SESSION_RESET:-0}" -gt "$(date +%s)" ]; then
  echo "$SESSION_RESET" > "$NOTIFY_FILE"
  WARNED_FILE="$CACHE_DIR/warned-for"
  WARNED=$(cat "$WARNED_FILE" 2>/dev/null || echo 0)
  # resets_at can drift a few seconds between responses; same window if within 5 min.
  if [ $(( SESSION_RESET - WARNED )) -gt 300 ] || [ $(( WARNED - SESSION_RESET )) -gt 300 ]; then
    echo "$SESSION_RESET" > "$WARNED_FILE"
    MINS=$(( (SESSION_RESET - $(date +%s)) / 60 ))
    if [ "$MINS" -lt 60 ]; then IN="$MINS min"; else IN="$(( MINS / 60 )) h $(( MINS % 60 )) min"; fi
    # shellcheck disable=SC2059
    notify "$(printf "$T_WARN_TITLE" "$SESSION_PCT")" "$(printf "$T_WARN_BODY" "$(date -r "$SESSION_RESET" +%H:%M)" "$IN")"
  fi
fi
[ -f "$NOTIFY_FILE" ] && ARMED="$T_NOTIFY_ARMED"

# Update check: at most once a day, against the latest GitHub release.
LATEST=""
if [ -z "$CLAUDE_USAGE_FIXTURE" ]; then
  LATEST_FILE="$CACHE_DIR/latest-version"
  if [ ! -f "$LATEST_FILE" ] || [ -n "$(find "$LATEST_FILE" -mtime +0 2>/dev/null)" ]; then
    TAG=$(curl -s -m 5 "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name // empty' 2>/dev/null)
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
  --arg session "$T_SESSION" --arg weekly "$T_WEEKLY" --arg weeklyModel "$T_WEEKLY_MODEL" \
  --arg resets "$T_RESETS" --arg day "$T_DAY" --arg extra "$T_EXTRA" --arg extraOff "$T_EXTRA_OFF" \
  --arg open "$T_OPEN" --arg refresh "$T_REFRESH" --arg noData "$T_NO_DATA" --arg url "$USAGE_URL" \
  --arg note "${NOTE:-}" --arg armed "${ARMED:-}" --arg display "${CLAUDE_USAGE_DISPLAY:-both}" \
  --arg update "${UPDATE:-}" --arg updateLabel "$T_UPDATE" --arg updateInstall "$T_UPDATE_INSTALL" \
  --arg releaseNotes "$T_RELEASE_NOTES" --arg repo "$REPO" '
  def left: (.resets_at // "" | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch null)
    | if . == null then "" else . - now
      | if . < 0 then ""
        elif . < 3600 then "\(. / 60 | floor) min"
        elif . < 86400 then "\(. / 3600 | floor) h \((. % 3600) / 60 | floor) min"
        else "\(. / 86400 | floor) \($day) \((. % 86400) / 3600 | floor) h" end
      | if . == "" then "" else "  \($resets) \(.)" end end;
  def color(p): if p >= 90 then "#e5484d" elif p >= 70 then "#f5a524" else null end;
  def bar(p): (p / 10 | floor | if . > 10 then 10 elif . < 0 then 0 else . end) as $n
    | ([range(0; $n)] | map("█") | join("")) + ([range(0; 10 - $n)] | map("░") | join(""));
  def pie(p): if p < 12.5 then "○" elif p < 37.5 then "◔" elif p < 62.5 then "◑" elif p < 87.5 then "◕" else "●" end;
  def title: if .kind == "session" then $session
    elif .kind == "weekly_all" then $weekly
    else "\($weeklyModel) \(.scope.model.display_name // .scope.surface // .kind)" end;
  def opts(p): " href=\($url)" + (if color(p) then " color=\(color(p))" else "" end);

  # Older responses only have five_hour / seven_day.
  (.limits // ([
      (.five_hour | select(. != null) | {kind: "session", percent: (.utilization | floor), resets_at}),
      (.seven_day | select(. != null) | {kind: "weekly_all", percent: (.utilization | floor), resets_at})
    ])) as $limits
  | ([$limits[] | select(.kind == "session") | .percent] | first) as $s
  | ([$limits[] | select(.kind == "weekly_all") | .percent] | first) as $w
  | ([$limits[].percent] | max // 0) as $top
  # CLAUDE_USAGE_DISPLAY: both | session | max | icon
  | (if $limits == [] then "✳ –"
     elif $display == "session" and $s != null then "✳ \($s)%"
     elif $display == "max" then "✳ \($top)%"
     elif $display == "icon" then "✳ \(pie($top))"
     elif $s != null and $w != null then "✳ \($s)% · \($w)%"
     else "✳ \($top)%" end)
    + (if $update != "" then " ↑" else "" end)
    + (if color($top) then " | color=\(color($top))" else "" end),
    "---",
    (if $update != "" then
       "⬆ \($updateLabel): v\($update) | color=#3b82f6",
       "\($updateInstall) | bash=/bin/bash param1=-c param2=\"bash <(curl -fsSL https://raw.githubusercontent.com/\($repo)/main/install.sh)\" terminal=false refresh=true",
       "\($releaseNotes) | href=https://github.com/\($repo)/releases/latest",
       "---"
     else empty end),
    (if $note != "" then "⚠ \($note) | color=gray", "---" else empty end),
    (if $limits == [] then $noData else empty end),
    ($limits[] | "\(title)  \(.percent)% | font=Menlo size=12" + opts(.percent),
                 "\(bar(.percent))\(left) | font=Menlo size=11 href=\($url)"),
    (if $armed != "" then "🔔 \($armed) | color=gray size=11" else empty end),
    "---",
    (.extra_usage // {} | if .is_enabled then "\($extra): \(.used_credits // 0) / \(.monthly_limit // "∞")" else $extraOff end),
    "---",
    "\($open) | href=\($url)",
    "\($refresh) | refresh=true"
' <<<"$BODY"
