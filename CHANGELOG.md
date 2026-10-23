# Changelog

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
