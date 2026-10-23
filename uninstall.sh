#!/bin/bash
# Removes the Claude Usage plugin and its cache. SwiftBar itself is left installed.
set -euo pipefail

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar-plugins")
rm -f "$PLUGIN_DIR"/claude-usage.*.sh
rm -rf "$HOME/Library/Caches/claude-usage-swiftbar"
if pgrep -xq SwiftBar; then open -g "swiftbar://refreshallplugins"; fi
echo "Claude Usage plugin removed. To remove SwiftBar too: brew uninstall --cask swiftbar"
