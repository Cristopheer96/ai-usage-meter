#!/bin/bash
# <xbar.title>Claude Usage</xbar.title>
# <xbar.version>v1.0.0</xbar.version>
# <xbar.author>Cristopher Huaroc</xbar.author>
# <xbar.desc>Shows your Claude plan usage (5-hour session and weekly limits) in the menu bar, using your Claude Code login.</xbar.desc>
# <xbar.dependencies>bash,jq,curl,Claude Code</xbar.dependencies>
# <xbar.abouturl>https://github.com/Cristopheer96/claude-usage-swiftbar</xbar.abouturl>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.environment>[CLAUDE_USAGE_LANG=auto]</swiftbar.environment>

# Unofficial: reads the same endpoint Claude Code's /usage command uses. It may change without notice.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
USAGE_URL="https://claude.ai/settings/usage"

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
    T_EXPIRED="Token vencido: abre Claude Code para renovarlo"; T_NO_DATA="Sin límites que mostrar" ;;
  *)
    T_SESSION="Session (5 h)"; T_WEEKLY="Weekly (all models)"; T_WEEKLY_MODEL="Weekly"
    T_RESETS="resets in"; T_DAY="d"; T_EXTRA="Extra usage"; T_EXTRA_OFF="Extra usage: off"
    T_OPEN="Open usage on claude.ai"; T_REFRESH="Refresh"; T_NO_CREDS="No Claude Code login found in Keychain"
    T_LOGIN="Install Claude Code and sign in with: claude"; T_ERROR="Could not fetch usage"
    T_EXPIRED="Token expired: open Claude Code to refresh it"; T_NO_DATA="No limits to show" ;;
esac

# CLAUDE_USAGE_FIXTURE=path/to.json renders a saved response instead of calling the API (for testing).
if [ -n "$CLAUDE_USAGE_FIXTURE" ]; then
  BODY=$(cat "$CLAUDE_USAGE_FIXTURE")
else
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    echo "✳ ? | color=gray"; echo "---"; echo "$T_NO_CREDS"; echo "$T_LOGIN"; exit 0
  fi
  RESPONSE=$(curl -s -m 10 -w '\n%{http_code}' https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20")
  CODE=$(tail -n1 <<<"$RESPONSE"); BODY=$(sed '$d' <<<"$RESPONSE")
  if [ "$CODE" != "200" ]; then
    echo "✳ ⚠ | color=orange"; echo "---"; echo "$T_ERROR ($CODE)"
    [ "$CODE" = "401" ] && echo "$T_EXPIRED"
    echo "$T_REFRESH | refresh=true"; exit 0
  fi
fi

jq -r \
  --arg session "$T_SESSION" --arg weekly "$T_WEEKLY" --arg weeklyModel "$T_WEEKLY_MODEL" \
  --arg resets "$T_RESETS" --arg day "$T_DAY" --arg extra "$T_EXTRA" --arg extraOff "$T_EXTRA_OFF" \
  --arg open "$T_OPEN" --arg refresh "$T_REFRESH" --arg noData "$T_NO_DATA" --arg url "$USAGE_URL" '
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
  | (if $s != null and $w != null then "✳ \($s)% · \($w)%"
     elif $limits == [] then "✳ –"
     else "✳ \($top)%" end) + (if color($top) then " | color=\(color($top))" else "" end),
    "---",
    (if $limits == [] then $noData else empty end),
    ($limits[] | "\(title)  \(.percent)% | font=Menlo size=12" + opts(.percent),
                 "\(bar(.percent))\(left) | font=Menlo size=11 href=\($url)"),
    "---",
    (.extra_usage // {} | if .is_enabled then "\($extra): \(.used_credits // 0) / \(.monthly_limit // "∞")" else $extraOff end),
    "---",
    "\($open) | href=\($url)",
    "\($refresh) | refresh=true"
' <<<"$BODY"
