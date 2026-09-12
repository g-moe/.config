#!/usr/bin/env bash
set -euo pipefail

server_dir="${BETTER_VSCODE_TEST_SERVER_DIR:?Set BETTER_VSCODE_TEST_SERVER_DIR to an extracted VSCodium Web Host release}"

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/better-vscode-test.XXXXXX")"
export BETTER_VSCODE_TEST_BASELINE="${BETTER_VSCODE_TEST_BASELINE:-$package_dir/tests/browser/baseline.json}"
export BETTER_VSCODE_TEST_REPORT="$test_dir/result.txt"
extensions_dir="$test_dir/server/extensions"

mkdir -p "$test_dir/server/data/Machine" "$test_dir/workspace" \
  "$extensions_dir/gary-ix.better-vscode" "$extensions_dir/local.better-vscode-tests"

# Git view tests need a repository in the disposable workspace.
git -C "$test_dir/workspace" init -q -b garrett/test-workspace

cp "$package_dir/package.json" "$package_dir/icon.png" "$package_dir/LICENSE" \
  "$extensions_dir/gary-ix.better-vscode/"
cp -R "$package_dir/dist" "$extensions_dir/gary-ix.better-vscode/"
cp -R "$package_dir/dist-test" "$extensions_dir/local.better-vscode-tests/"

cat > "$extensions_dir/local.better-vscode-tests/package.json" <<'JSON'
{
  "name": "better-vscode-tests",
  "publisher": "local",
  "version": "0.0.1",
  "engines": { "vscode": "^1.96.0" },
  "main": "./dist-test/tests/browser/extension.js",
  "extensionKind": ["workspace"],
  "contributes": {
    "keybindings": [
      { "command": "better-vscode.tests.continue", "key": "f19" },
      { "command": "better-vscode.terminal.focus", "key": "f17" },
      { "command": "better-vscode.terminal.focusAndMaximize", "key": "f18" }
    ],
    "commands": [{
      "command": "better-vscode.tests.terminal",
      "title": "better-vscode Tests: Run Terminal Tests"
    }]
  }
}
JSON

cat > "$test_dir/server/data/Machine/settings.json" <<'JSON'
{
  "terminal.integrated.profiles.osx": {
    "Test Shell": { "path": "/bin/bash", "args": ["--noprofile", "--norc"] }
  },
  "terminal.integrated.defaultProfile.osx": "Test Shell",
  "terminal.integrated.confirmOnKill": "never",
  "workbench.startupEditor": "none"
}
JSON

export BETTER_VSCODE_TEST_VERSION
BETTER_VSCODE_TEST_VERSION="$(node -p 'require(process.argv[1]).version' "$server_dir/package.json")"
echo "Server version: $BETTER_VSCODE_TEST_VERSION"
echo "Open: http://127.0.0.1:${BETTER_VSCODE_TEST_PORT:-8765}/?folder=$test_dir/workspace"
echo "Run: better-vscode Tests: Run Terminal Tests"
echo "Test result: $BETTER_VSCODE_TEST_REPORT"
echo "Stop the server with Ctrl+C when finished."

"$server_dir/bin/codium-server" \
  --host 127.0.0.1 \
  --port "${BETTER_VSCODE_TEST_PORT:-8765}" \
  --without-connection-token \
  --server-data-dir "$test_dir/server" \
  --extensions-dir "$extensions_dir" \
  --telemetry-level off \
  --accept-server-license-terms
