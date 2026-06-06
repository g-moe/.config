#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/interactive.sh"
. "$LIB_DIR/utils.sh"

load_homebrew() {
  if has_command brew; then
    return
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_cask() {
  local cask_name="$1"

  if brew_has_cask "$cask_name"; then
    log_info "$cask_name already installed."
    return
  fi

  log_info "Installing $cask_name..."
  brew install --cask "$cask_name"
  log_info "$cask_name installed."
}

install_formula() {
  local formula_name="$1"

  if brew_has_formula "$formula_name"; then
    log_info "$formula_name already installed."
    return
  fi

  log_info "Installing $formula_name..."
  brew install "$formula_name"
  log_info "$formula_name installed."
}

install_tailscale() {
  local choice
  choice="$(interactive_select 'How do you want to install Tailscale?' 'Skip' 'CLI (system service)' 'App (GUI)')"

  case "$choice" in
    0)
      log_info 'Skipping Tailscale install.'
      ;;
    1)
      if brew_has_formula tailscale; then
        log_info 'Tailscale CLI already installed.'
        return
      fi

      if brew_has_cask tailscale-app; then
        log_info 'Removing tailscale-app so the boot-time daemon can be used instead.'
        brew uninstall --cask tailscale-app
      fi

      install_formula tailscale

      if sudo brew services list | grep -Eq '^tailscale\s+started\b'; then
        log_info 'tailscale service already started.'
        return
      fi

      log_info 'Starting tailscale system service...'
      sudo brew services start tailscale
      log_info 'tailscale system service started.'
      log_info 'Run sudo tailscale up to authenticate this Mac if it is not already connected.'
      ;;
    2)
      if brew_has_cask tailscale-app; then
        log_info 'Tailscale app already installed.'
        return
      fi

      if brew_has_formula tailscale; then
        log_info 'Removing tailscale CLI so the GUI app can be used instead.'

        if sudo brew services list | grep -Eq '^tailscale\s+started\b'; then
          log_info 'Stopping tailscale system service...'
          sudo brew services stop tailscale || true
        fi

        if brew uninstall tailscale; then
          log_info 'Tailscale CLI uninstalled.'
        else
          log_info 'brew uninstall failed, cleaning up manually...'
          local tailscale_cellar
          tailscale_cellar="$(brew --cellar tailscale)"
          if [[ -n "$tailscale_cellar" && -d "$tailscale_cellar" ]]; then
            sudo rm -rf "$tailscale_cellar"
            log_info 'Removed tailscale cellar manually.'
          fi
          brew cleanup tailscale || true
        fi
      fi

      install_cask tailscale-app
      ;;
  esac
}

install_nordvpn() {
  local choice
  choice="$(interactive_select 'Install NordVPN?' 'Skip' 'Install')"

  case "$choice" in
    0)
      log_info 'Skipping NordVPN install.'
      ;;
    1)
      install_cask nordvpn
      ;;
  esac
}

install_opencode_desktop() {
  if brew_has_cask opencode-desktop; then
    log_info 'opencode-desktop already installed.'
    return
  fi

  if [[ -d /Applications/OpenCode.app || -d "$HOME/Applications/OpenCode.app" ]]; then
    log_info 'OpenCode.app already present; skipping Homebrew install.'
    return
  fi

  install_cask opencode-desktop
}

ensure_brew_available() {
  load_homebrew

  if ! has_command brew; then
    log_error 'Homebrew is required to install Mac software.'
    log_error 'Run scripts/mac-install.sh first to install Homebrew.'
    exit 1
  fi
}

main() {
  run_step 'Validate Homebrew' ensure_brew_available
  run_step 'Install Ghostty' install_cask ghostty
  run_step 'Install Karabiner-Elements' install_cask karabiner-elements
  run_step 'Install BetterDisplay' install_cask betterdisplay
  run_step 'Install Tailscale' install_tailscale
  run_step 'Install NordVPN' install_nordvpn
  run_step 'Install balenaEtcher' install_cask balenaetcher
  run_step 'Install Raycast' install_cask raycast
  run_step 'Install VSCodium' install_cask vscodium
  run_step 'Install Codex' install_cask codex-app
  run_step 'Install OpenCode Desktop' install_opencode_desktop
  run_step 'Install Docker Desktop' install_cask docker-desktop
  run_step 'Install UTM' install_cask utm
  run_step 'Install Google Chrome' install_cask google-chrome
  run_step 'Install Firefox' install_cask firefox
  run_step 'Install Zen Browser' install_cask zen
  run_step 'Install Brave Browser' install_cask brave-browser
  run_step 'Install Helium' install_cask helium
  run_step 'Install Homerow' install_cask homerow
  run_step 'Install GIMP' install_cask gimp
  run_step 'Install Fastfetch' install_formula fastfetch
  run_step 'Install Neovim' install_formula neovim
  run_step 'Install VoiceInk' install_cask voiceink
  run_step 'Install TG Pro' install_cask tg-pro
  run_step 'Install iStat Menus' install_cask istat-menus
}

main "$@"
