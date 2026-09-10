#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${HOME}/.dotfiles"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_link() {
  local source="$1"
  local target="$2"

  [[ -L "$target" ]] || fail "$target is not a symlink"
  [[ "$(readlink "$target")" == "$source" ]] ||
    fail "$target points to $(readlink "$target"), expected $source"
  [[ -e "$target" ]] || fail "$target is broken"
}

[[ -d "$ROOT_DIR/.git" ]] || fail "$ROOT_DIR is not the Git repo"

for app in ghostty nvim karabiner; do
  [[ ! -L "$HOME/.config/$app" ]] || fail "$HOME/.config/$app links a whole folder"
done

while IFS= read -r source; do
  relative="${source#"$ROOT_DIR/nvim/"}"
  expect_link "$source" "$HOME/.config/nvim/$relative"
done < <(find "$ROOT_DIR/nvim" -type f | sort)

expect_link "$ROOT_DIR/codex/.codex/config.toml" "$HOME/.codex/config.toml"
expect_link "$ROOT_DIR/codex/.codex/keybindings.json" "$HOME/.codex/keybindings.json"
expect_link "$ROOT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
expect_link "$ROOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
expect_link "$ROOT_DIR/zsh/.zshenv" "$HOME/.zshenv"
expect_link "$ROOT_DIR/zsh/.zprofile" "$HOME/.zprofile"
expect_link "$ROOT_DIR/zsh/.zshrc" "$HOME/.zshrc"
expect_link "$ROOT_DIR/packages/lib/bash/bin/shared-copy-to-clipboard.sh" "$HOME/.local/bin/copy-to-clipboard"

case "$(uname -s)" in
  Darwin)
    expect_link "$ROOT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    expect_link "$ROOT_DIR/ghostty/themes/gtheme-dark" "$HOME/.config/ghostty/themes/gtheme-dark"
    expect_link "$ROOT_DIR/ghostty/themes/gtheme-light" "$HOME/.config/ghostty/themes/gtheme-light"
    expect_link "$ROOT_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    expect_link "$ROOT_DIR/packages/mac/mactop/config.json" "$HOME/.mactop/config.json"
    expect_link "$ROOT_DIR/packages/mac/mactop/com.dotfiles.mactop-menubar.plist" "$HOME/Library/LaunchAgents/com.dotfiles.mactop-menubar.plist"
    expect_link "$ROOT_DIR/arc/StorableLinkRouting.json" "$HOME/Library/Application Support/Arc/StorableLinkRouting.json"
    vscodium="$HOME/Library/Application Support/VSCodium/User"
    ;;
  Linux)
    vscodium="$HOME/.config/VSCodium/User"
    ;;
  *) fail "unsupported OS: $(uname -s)" ;;
esac

expect_link "$ROOT_DIR/vscode/user/settings.json" "$vscodium/settings.json"
expect_link "$ROOT_DIR/vscode/user/keybindings.json" "$vscodium/keybindings.json"
expect_link "$ROOT_DIR/vscode/user/personal.code-snippets" "$vscodium/snippets/personal.code-snippets"

printf 'Installed links point to ~/.dotfiles and are not broken.\n'
