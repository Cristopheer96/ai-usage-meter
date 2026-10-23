# AI Usage Meter

[![CI](https://github.com/Cristopheer96/ai-usage-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/Cristopheer96/ai-usage-meter/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/Cristopheer96/ai-usage-meter)](https://github.com/Cristopheer96/ai-usage-meter/releases/latest) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Your **Claude Code** and **Codex** usage limits in the macOS menu bar.

![Menu bar dropdown](docs/screenshot.png)

- 5-hour and weekly limits, with time until each one resets.
- Notifications at 90% and when your session resets.
- English and Spanish. No Homebrew needed.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Cristopheer96/ai-usage-meter/main/install.sh | bash
```

You need macOS and at least one of: [Claude Code](https://docs.claude.com/en/docs/claude-code) signed in (`claude`), or [Codex](https://developers.openai.com/codex) used once.

The first time, macOS asks two things: let SwiftBar read `Claude Code-credentials` (**Always Allow**) and let **AI Usage Meter** send notifications (**Allow**).

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/Cristopheer96/ai-usage-meter/main/uninstall.sh | bash
```

## How it works

It's a [SwiftBar](https://swiftbar.app) plugin: one short bash script, [`claude-usage.5m.sh`](claude-usage.5m.sh), that refreshes every 5 minutes.

- **Claude:** reads your Claude Code token from the Keychain and asks `api.anthropic.com` for your usage, the same call `/usage` makes. The token never goes anywhere else.
- **Codex:** reads the limits Codex saves in `~/.codex/sessions`. No network calls; the value updates when you use Codex.

The installer adds SwiftBar and `jq` only if missing (SHA-256 checked) and builds a small notifier app on your Mac.

## Settings

In SwiftBar: click the item → **SwiftBar** → **Configure Plugin**.

| Variable | Values |
| --- | --- |
| `USAGE_PROVIDERS` | `auto` (one item each, default), `claude`, `codex`, `both` (one item) |
| `CLAUDE_USAGE_DISPLAY` | `both` (`6% · 20%`), `session`, `max`, `icon` (`◔`) |
| `CLAUDE_USAGE_NOTIFY_AT` | Percent for alerts, default `90`; `0` turns them off |
| `CLAUDE_USAGE_LANG` | `auto`, `en`, `es` |

## Troubleshooting

- **`⚠` on the Claude item:** error 401 means the token expired (open Claude Code once); 429 means rate limited (it retries by itself).
- **No notifications:** allow **AI Usage Meter** in System Settings → Notifications.
- **No icon in the bar:** the bar is full; hold ⌘ and drag icons to make room.

## Contributing

Issues and PRs are welcome. Before opening a PR:

```bash
tests/run.sh
shellcheck claude-usage.5m.sh install.sh uninstall.sh tests/run.sh notifier/build.sh
```

Tests use the responses in [`fixtures/`](fixtures); new fixtures from other plans help a lot. Releases are listed in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE). Not affiliated with Anthropic or OpenAI. Claude and OpenAI are trademarks of their owners; their icons are used only to identify each service (OpenAI logo from [Simple Icons](https://simpleicons.org), CC0). This relies on unofficial data sources that may change.

---

**En español:** muestra tu uso de Claude Code y Codex en la barra de menú de macOS, con avisos al 90 % y cuando se reinicia la sesión. Se instala con el comando de arriba y se configura en SwiftBar → **Configure Plugin** (`CLAUDE_USAGE_LANG=es` para forzar español).
