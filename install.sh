#!/bin/bash
# Installs the Claude Usage menu bar plugin for SwiftBar.
# Usage: curl -fsSL https://raw.githubusercontent.com/Cristopheer96/claude-usage-swiftbar/main/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Cristopheer96/claude-usage-swiftbar/main"
PLUGIN="claude-usage.5m.sh"
DEFAULT_DIR="$HOME/.swiftbar-plugins"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mx\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "This plugin only works on macOS."

# SwiftBar
if [ -d "/Applications/SwiftBar.app" ] || [ -d "$HOME/Applications/SwiftBar.app" ]; then
  info "SwiftBar already installed"
elif command -v brew >/dev/null; then
  info "Installing SwiftBar with Homebrew"
  brew install --cask swiftbar
else
  fail "SwiftBar not found and Homebrew is missing. Install SwiftBar from https://swiftbar.app and run this again."
fi

# jq (ships with macOS 15+, otherwise via Homebrew)
if ! command -v jq >/dev/null; then
  command -v brew >/dev/null || fail "jq is required. Install Homebrew (https://brew.sh) or jq, then run this again."
  info "Installing jq with Homebrew"
  brew install jq
fi

# Plugin folder: reuse SwiftBar's if already set
PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR="$DEFAULT_DIR"
  defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"
fi
mkdir -p "$PLUGIN_DIR"
rm -f "$PLUGIN_DIR"/claude-usage.*.sh  # drop older versions with another interval

# Copy from a local clone if present, otherwise download
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$PLUGIN" ]; then
  cp "$SCRIPT_DIR/$PLUGIN" "$PLUGIN_DIR/$PLUGIN"
else
  info "Downloading plugin"
  curl -fsSL "$REPO_RAW/$PLUGIN" -o "$PLUGIN_DIR/$PLUGIN"
fi
chmod +x "$PLUGIN_DIR/$PLUGIN"
info "Plugin installed in $PLUGIN_DIR"

# Small notifier app so notifications show their own icon instead of Script Editor's
NOTIFIER_SRC="$SCRIPT_DIR/notifier"
if [ -z "$SCRIPT_DIR" ] || [ ! -f "$NOTIFIER_SRC/build.sh" ]; then
  NOTIFIER_SRC=$(mktemp -d)
  for f in build.sh notify.applescript icon.icns; do
    curl -fsSL "$REPO_RAW/notifier/$f" -o "$NOTIFIER_SRC/$f"
  done
fi
mkdir -p "$HOME/Applications"
if bash "$NOTIFIER_SRC/build.sh" "$NOTIFIER_SRC" "$HOME/Applications/AI Usage Meter.app"; then
  info "Notifier app installed in ~/Applications"
else
  warn "Could not build the notifier app; notifications will use Script Editor's icon."
fi

# Claude Code login is where the token comes from
if ! security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; then
  warn "No Claude Code login found. Install Claude Code and run 'claude' to sign in; the plugin will pick it up."
fi

if pgrep -xq SwiftBar; then
  open -g "swiftbar://refreshallplugins"
else
  open -a SwiftBar
fi
info "Done. Look for ✳ in your menu bar."
warn "macOS may ask to allow notifications from \"AI Usage Meter\": choose Allow."
warn "The first time, macOS may ask to allow SwiftBar to read the \"Claude Code-credentials\" Keychain item: choose Always Allow."
