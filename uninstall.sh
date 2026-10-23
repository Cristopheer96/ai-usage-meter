#!/bin/bash
# Removes the Claude Usage plugin. SwiftBar itself is left installed.
set -euo pipefail

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar-plugins")
rm -f "$PLUGIN_DIR"/claude-usage.*.sh
pgrep -xq SwiftBar && open -g "swiftbar://refreshallplugins"
echo "Claude Usage plugin removed. To remove SwiftBar too: brew uninstall --cask swiftbar"
