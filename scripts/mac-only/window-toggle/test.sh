#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_BIN="${TMPDIR:-/tmp}/window-toggle-tests"

/usr/bin/swiftc -typecheck "$SCRIPT_DIR/Sources/WindowToggleCore.swift" "$SCRIPT_DIR/Sources/main.swift"
/usr/bin/swiftc "$SCRIPT_DIR/Sources/WindowToggleCore.swift" "$SCRIPT_DIR/Tests/WindowToggleCoreTests.swift" -o "$TEST_BIN"
"$TEST_BIN"
