#!/bin/bash
# Removes the AI Usage Meter plugins, notifier app, downloaded jq and cache. SwiftBar itself is left installed.
set -euo pipefail

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar-plugins")
rm -f "$PLUGIN_DIR"/claude-usage.*.sh "$PLUGIN_DIR"/codex-usage.*.sh
rm -rf "$HOME/Library/Caches/claude-usage-swiftbar" "$HOME/Applications/AI Usage Meter.app" "$HOME/Applications/Usage Meter for Claude.app" \
  "$HOME/Library/Application Support/AI Usage Meter"
if pgrep -xq SwiftBar; then open -g "swiftbar://refreshallplugins"; fi
echo "AI Usage Meter removed (Claude and Codex items, notifier app, cache). SwiftBar is still installed; remove it from Applications if you no longer need it."
