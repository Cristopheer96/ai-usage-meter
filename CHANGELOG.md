# Changelog

## v1.5.1 - 2026-10-23

- The repo is now `Cristopheer96/ai-usage-meter` (it covers Claude and Codex). Old links redirect.
- The update check follows redirects.

## v1.5.0 - 2026-10-23

- Codex support: 5-hour and weekly limits read from Codex's local session logs (no network calls), shown next to Claude as `◎ 24% · 24%`.
- The 90% warning and the reset notification work for Codex too.
- Claude and Codex are two separate menu bar items, each with its own icon (the Claude Code pixel mascot for Claude, the OpenAI logo for Codex). The installer adds the ones you use.
- Homebrew is no longer required: without it, the installer downloads the notarized SwiftBar release and the official jq binary, both checked against pinned SHA-256 hashes.
- CI installs on clean macOS 14 (Apple silicon) and macOS 15 (Intel) machines.
- `USAGE_PROVIDERS` picks what to show: `auto` (default, by file name), `claude`, `codex` or `both` (one combined item).

## v1.4.1 - 2026-10-23

- Wait at least 5 minutes after a 429, even when the API sends `retry-after: 0`.

## v1.4.0 - 2026-10-23

- Notifications come from a small "AI Usage Meter" app with its own icon, instead of Script Editor. The installer builds it locally with `osacompile`; `osascript` remains the fallback.

## v1.3.0 - 2026-10-23

- Notification when your session reaches `CLAUDE_USAGE_NOTIFY_AT` (90% by default), once per 5-hour window, with the reset time.

## v1.2.0 - 2026-10-23

- Notification when your 5-hour session resets, if you went above 90% (`CLAUDE_USAGE_NOTIFY_AT`).
- Choose what the menu bar shows: `both`, `session`, `max` or `icon` (`CLAUDE_USAGE_DISPLAY`).
- Daily check for a new release, with an "Install update" item in the menu.
- Tests and shellcheck on every push and PR.

## v1.1.0 - 2026-10-23

- Handle rate limits (HTTP 429): show the last data instead of an error, honor `retry-after`.
- Refresh every 5 minutes instead of 2. The installer removes the old 2-minute version.

## v1.0.0 - 2026-10-23

- First release: session, weekly and per-model limits in the menu bar, English and Spanish, one-line installer.
