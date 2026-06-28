#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Arc Windows
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/Arc.app/Contents/Resources/AppIcon.icns
# @raycast.packageName Window Tools

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="${TMPDIR:-/tmp}/arc-window-toggle"
CORE="$SCRIPT_DIR/window-toggle/Sources/WindowToggleCore.swift"
MAIN="$SCRIPT_DIR/window-toggle/Sources/main.swift"

if [[ ! -x "$BIN" || "$CORE" -nt "$BIN" || "$MAIN" -nt "$BIN" ]]; then
  /usr/bin/swiftc "$CORE" "$MAIN" -o "$BIN"
fi

"$BIN" \
  "Arc" \
  "company.thebrowser.Browser" \
  "arc-window-toggle.state"
