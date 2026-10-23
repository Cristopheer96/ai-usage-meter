#!/bin/bash
# Installs the AI Usage Meter menu bar plugins (Claude and Codex) for SwiftBar. Homebrew is optional.
# Usage: curl -fsSL https://raw.githubusercontent.com/Cristopheer96/claude-usage-swiftbar/main/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Cristopheer96/claude-usage-swiftbar/main"
PLUGIN="claude-usage.5m.sh"
DEFAULT_DIR="$HOME/.swiftbar-plugins"
BIN_DIR="$HOME/Library/Application Support/AI Usage Meter/bin"
# Pinned downloads used when Homebrew is not available.
SWIFTBAR_URL="https://github.com/swiftbar/SwiftBar/releases/download/v2.1.1/SwiftBar.v2.1.1.b597.zip"
SWIFTBAR_SHA256="fcdec490782d6587046304044951c63de49ac422fc63892a6fab2dd7bc70c0cd"
JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.8.2"
JQ_SHA256_ARM64="2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e"
JQ_SHA256_AMD64="e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0"
# AI_USAGE_NO_BREW=1 ignores Homebrew; AI_USAGE_NO_LAUNCH=1 skips starting SwiftBar (used by CI).
if [ -z "${AI_USAGE_NO_BREW:-}" ]; then export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; fi
export PATH="$BIN_DIR:$PATH"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mx\033[0m %s\n' "$1" >&2; exit 1; }
has_brew() { [ -z "${AI_USAGE_NO_BREW:-}" ] && command -v brew >/dev/null; }
# download <url> <sha256> <output>
download() {
  curl -fsSL "$1" -o "$3" || fail "Could not download $1"
  [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" = "$2" ] || { rm -f "$3"; fail "Checksum mismatch for $1"; }
}

[ "$(uname)" = "Darwin" ] || fail "This plugin only works on macOS."

# SwiftBar: Homebrew if available, otherwise the notarized release from GitHub
if [ -d "/Applications/SwiftBar.app" ] || [ -d "$HOME/Applications/SwiftBar.app" ]; then
  info "SwiftBar already installed"
elif has_brew; then
  info "Installing SwiftBar with Homebrew"
  brew install --cask swiftbar
else
  info "Downloading SwiftBar"
  APPS="/Applications"; [ -w "$APPS" ] || { APPS="$HOME/Applications"; mkdir -p "$APPS"; }
  ZIP=$(mktemp -d)/SwiftBar.zip
  download "$SWIFTBAR_URL" "$SWIFTBAR_SHA256" "$ZIP"
  # ditto keeps the code signature intact (unzip breaks it)
  ditto -x -k "$ZIP" "$APPS"
  rm -f "$ZIP"
  codesign --verify --deep --strict "$APPS/SwiftBar.app" || fail "SwiftBar signature check failed"
  info "SwiftBar installed in $APPS"
fi

# jq: ships with macOS 15+; otherwise Homebrew or the official binary
if ! command -v jq >/dev/null; then
  if has_brew; then
    info "Installing jq with Homebrew"
    brew install jq
  else
    info "Downloading jq"
    mkdir -p "$BIN_DIR"
    if [ "$(uname -m)" = "arm64" ]; then
      download "$JQ_URL/jq-macos-arm64" "$JQ_SHA256_ARM64" "$BIN_DIR/jq"
    else
      download "$JQ_URL/jq-macos-amd64" "$JQ_SHA256_AMD64" "$BIN_DIR/jq"
    fi
    chmod +x "$BIN_DIR/jq"
  fi
fi
jq --version >/dev/null || fail "jq is not working"

# Plugin folder: reuse SwiftBar's if already set
PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR="$DEFAULT_DIR"
  defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"
fi
mkdir -p "$PLUGIN_DIR"
rm -f "$PLUGIN_DIR"/claude-usage.*.sh "$PLUGIN_DIR"/codex-usage.*.sh  # drop older versions

# Copy from a local clone if present, otherwise download
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
SOURCE=$(mktemp)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$PLUGIN" ]; then
  cp "$SCRIPT_DIR/$PLUGIN" "$SOURCE"
else
  info "Downloading plugin"
  curl -fsSL "$REPO_RAW/$PLUGIN" -o "$SOURCE"
fi

# One menu bar item per provider; the file name tells the script which one it is.
HAS_CLAUDE=$(security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1 && echo yes || true)
HAS_CODEX=$([ -d "${CODEX_HOME:-$HOME/.codex}/sessions" ] && echo yes || true)
if [ -n "$HAS_CLAUDE" ] || [ -z "$HAS_CODEX" ]; then
  install -m 755 "$SOURCE" "$PLUGIN_DIR/$PLUGIN"
  info "Claude item installed"
fi
if [ -n "$HAS_CODEX" ]; then
  install -m 755 "$SOURCE" "$PLUGIN_DIR/codex-usage.5m.sh"
  info "Codex item installed"
fi
rm -f "$SOURCE"
[ -z "$HAS_CLAUDE$HAS_CODEX" ] && warn "No Claude Code login or Codex data found yet. Sign in to either one and run this installer again."
info "Plugins installed in $PLUGIN_DIR"

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

if [ -n "${AI_USAGE_NO_LAUNCH:-}" ]; then
  :
elif pgrep -xq SwiftBar; then
  open -g "swiftbar://refreshallplugins"
else
  open -a SwiftBar
fi
info "Done. Look for the Claude and Codex icons in your menu bar."
warn "macOS may ask to allow notifications from \"AI Usage Meter\": choose Allow."
warn "The first time, macOS may ask to allow SwiftBar to read the \"Claude Code-credentials\" Keychain item: choose Always Allow."
