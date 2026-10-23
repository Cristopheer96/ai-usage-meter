# AI Usage Meter for Claude Code and Codex (SwiftBar plugin)

[![CI](https://github.com/Cristopheer96/ai-usage-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/Cristopheer96/ai-usage-meter/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/Cristopheer96/ai-usage-meter)](https://github.com/Cristopheer96/ai-usage-meter/releases/latest) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

See your Claude and Codex plan limits in the macOS menu bar: the 5-hour session limit, the weekly limit and any per-model weekly limit, with time until each one resets.

![Menu bar dropdown](docs/screenshot.png)

Claude and Codex get one menu bar item each, with their own icon and menu: `[Claude icon] 6% · 20%` and `[OpenAI icon] 24% · 24%` (session · weekly). The installer only adds the ones you use. The numbers turn orange at 70% and red at 90%.

- <img src="docs/icon.png" width="20" align="top"> **Two notifications, for Claude and for Codex:** one when your 5-hour session reaches 90% ("Codex: 92% of your session used. Resets at 17:14 (in 1 h 20 min)") and another the moment it resets ("Claude is available again").
- **Rate-limit safe:** if Anthropic answers 429, it keeps showing the last data and waits as told.
- **Updates itself on request:** checks GitHub once a day and adds an "Install update" item when there is a new release.
- English and Spanish, following your macOS language.

> Not affiliated with or endorsed by Anthropic or OpenAI. For Claude it reads the same unofficial endpoint the Claude Code `/usage` command uses; for Codex it reads the rate limits Codex writes to its local session logs. Either may break if they change.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Cristopheer96/ai-usage-meter/main/install.sh | bash
```

The installer:

1. Installs [SwiftBar](https://swiftbar.app) if you don't have it: with Homebrew when available, otherwise the notarized release from GitHub (SHA-256 checked).
2. Installs `jq` if it's missing (macOS 15+ already ships it): with Homebrew, or the official binary (SHA-256 checked).
3. Adds a Claude item and/or a Codex item to your SwiftBar plugin folder (`~/.swiftbar-plugins` if none is set), depending on what you use, and starts SwiftBar.
4. Builds a tiny notifier app, `~/Applications/AI Usage Meter.app`, so notifications show their own icon. It is compiled on your Mac from [`notifier/`](notifier) with `osacompile`; no binaries are downloaded.

The first time it runs, macOS may ask whether SwiftBar can read the `Claude Code-credentials` Keychain item. Choose **Always Allow**.

Prefer to read it first? Clone the repo and run it locally:

```bash
git clone https://github.com/Cristopheer96/ai-usage-meter.git
cd ai-usage-meter
./install.sh
```

### Requirements

- macOS
- At least one of:
  - [Claude Code](https://docs.claude.com/en/docs/claude-code) signed in with a Claude subscription (Pro, Max, Team or Enterprise). Run `claude` once and log in.
  - [Codex](https://developers.openai.com/codex) (CLI or app) signed in with ChatGPT. Use it once so it writes its limits.
- Nothing else: Homebrew is optional.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/Cristopheer96/ai-usage-meter/main/uninstall.sh | bash
```

This removes the plugin, the notifier app and the cache, and leaves SwiftBar installed. Remove it with `brew uninstall --cask swiftbar`.

## Settings

Change these in SwiftBar: click the plugin → **SwiftBar** → **Configure Plugin**.

| What | How |
| --- | --- |
| Providers | `USAGE_PROVIDERS`: `auto` (default: the `claude-usage` item shows Claude and the `codex-usage` item shows Codex), `claude`, `codex`, or `both` to put both in a single item as `✳ 6% · 20%  ⬡ 24% · 24%`. |
| Language | English or Spanish, following your macOS language. `CLAUDE_USAGE_LANG=en` or `es` to force one. |
| Menu bar text | `CLAUDE_USAGE_DISPLAY`: `both` (`✳ 6% · 20%`, default), `session` (`✳ 6%`), `max` (highest limit, `✳ 27%`) or `icon` (`✳ ◔`). |
| Notifications | `CLAUDE_USAGE_NOTIFY_AT`: session % that triggers the warning and the reset alert (default `90`). `0` turns both off. |
| Refresh interval | The `5m` in the file name (every 5 minutes). Going much lower can hit the endpoint's rate limit; the plugin then shows the last data it got. |

## Privacy

- Claude: your token is read from the macOS Keychain entry Claude Code already creates and is only sent to `api.anthropic.com`, the same host Claude Code talks to. It is never written anywhere else.
- Codex: nothing is sent anywhere. The plugin only reads the rate-limit lines in `~/.codex/sessions` (or `$CODEX_HOME/sessions`).
- The script is a single short bash file: read [`claude-usage.5m.sh`](claude-usage.5m.sh) before installing.

## Troubleshooting

| You see | Meaning |
| --- | --- |
| `✳ ?` | No Claude Code login and no Codex data. Sign in to either one. |
| `🕘 As of your last Codex use: 22/10 11:13` | Codex only updates its limits while you use it, so this is the last known value. Windows that already reset show 0%. |
| `✳ ⚠` + error 401 | The token expired. Open Claude Code once and it refreshes it. |
| `⚠ Data from 15:40 (429)` in the menu | Anthropic rate-limited the request. The plugin shows the last data and retries by itself. |
| `✳ ⚠` + another code | The endpoint failed or changed. Open an issue. |
| `↑` next to the numbers | A new version is out. Open the menu → **Install update**. |
| No notifications | Allow **AI Usage Meter** in System Settings → Notifications, and check Focus / Do Not Disturb. |
| Nothing in the menu bar | The bar is full and macOS is hiding icons. Quit some apps or hold ⌘ and drag icons to reorder. |

## Development

Run the tests (they also run on every push and PR):

```bash
tests/run.sh
shellcheck claude-usage.5m.sh install.sh uninstall.sh tests/run.sh notifier/build.sh
```

Render a saved response instead of calling the API:

```bash
CLAUDE_USAGE_FIXTURE=fixtures/near-limit.json ./claude-usage.5m.sh
CLAUDE_USAGE_LANG=es CLAUDE_USAGE_FIXTURE=fixtures/team-with-model-limit.json ./claude-usage.5m.sh
CODEX_USAGE_FIXTURE=fixtures/codex-session.jsonl USAGE_PROVIDERS=codex ./claude-usage.5m.sh
```

`fixtures/` has a normal response, one near the limits, an older response without the `limits` array and an empty one. PRs with fixtures from other plans are welcome. See [CHANGELOG.md](CHANGELOG.md) for releases.

## License

[MIT](LICENSE)

The icons are used only to identify each service: the Claude item uses a redrawn Claude Code pixel mascot, and the Codex item uses the OpenAI logo from [Simple Icons](https://simpleicons.org) (CC0). Claude is a trademark of Anthropic and OpenAI is a trademark of OpenAI; this project is not affiliated with either. Icon sources are in [`icons/`](icons).

---

## En español

Muestra en la barra de menú de macOS tu uso de Claude y de Codex: el límite de sesión de 5 horas, el semanal y el semanal por modelo, con el tiempo que falta para cada reinicio.

**Instalar:**

```bash
curl -fsSL https://raw.githubusercontent.com/Cristopheer96/ai-usage-meter/main/install.sh | bash
```

Necesitas Claude Code con la sesión iniciada (`claude`), Codex, o los dos. Cada uno aparece solo si está instalado. El idioma sigue al de macOS. Te llega una notificación cuando tu sesión llega al 90 % y otra cuando se reinicia. Todo se configura en SwiftBar → el plugin → **Configure Plugin**:

- `USAGE_PROVIDERS=auto|claude|codex|both` para elegir cuáles mostrar. Por defecto Claude y Codex aparecen como dos elementos separados, cada uno con su ícono; `both` los junta en uno.
- `CLAUDE_USAGE_LANG=es` para forzar español.
- `CLAUDE_USAGE_DISPLAY=both|session|max|icon` para elegir qué se ve en la barra.
- `CLAUDE_USAGE_NOTIFY_AT=90` para el porcentaje de los avisos (`0` los apaga).

No es un proyecto oficial de Anthropic ni de OpenAI.
