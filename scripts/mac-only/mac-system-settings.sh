#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/interactive.sh"

create_black_background_image() {
  local image_path='/System/Library/Desktop Pictures/Solid Colors/Black.png'

  if [[ ! -f "$image_path" ]]; then
    log_error "Missing built-in black wallpaper: $image_path"
    exit 1
  fi

  printf '%s\n' "$image_path"
}

set_black_wallpaper() {
  local image_path="$1"

  osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to POSIX file "$image_path"
  end tell
end tell
EOF

  log_info "Wallpaper set to black: $image_path"
}

set_black_screensaver() {
  local image_path="$1"
  local image_dir='/System/Library/Desktop Pictures/Solid Colors'

  defaults -currentHost write com.apple.screensaver moduleDict -dict \
    moduleName 'iLifeSlideShows' \
    path '/System/Library/Frameworks/ScreenSaver.framework/PlugIns/iLifeSlideshows.saver' \
    type -int 0

  defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedSource -int 3
  defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedFolderPath -string "$image_dir"
  defaults -currentHost write com.apple.ScreenSaverPhotoChooser LastViewedPhotoPath -string "$image_path"
  defaults -currentHost write com.apple.ScreenSaverPhotoChooser ShufflesPhotos -bool false

  log_info 'Screen saver configured to use black image folder.'
}

disable_handoff() {
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
  killall useractivityd >/dev/null 2>&1 || true
  killall Dock >/dev/null 2>&1 || true

  log_info 'Handoff disabled.'
}

configure_trackpad() {
  defaults write -g com.apple.trackpad.scaling -float 5
  killall Dock >/dev/null 2>&1 || true
  killall SystemUIServer >/dev/null 2>&1 || true

  log_info 'Trackpad tracking speed set to 5.'
}

configure_keyboard_repeat() {
  defaults write NSGlobalDomain KeyRepeat -int 120
  defaults write NSGlobalDomain InitialKeyRepeat -int 25

  log_info 'Key repeat rate set to slow (120 ms).'
  log_info 'Delay until repeat set to shortest (225 ms).'
}

mac_file_associations() {
  local script_path="$SCRIPT_DIR/mac-file-associations.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Missing file associations script: $script_path"
    exit 1
  fi

  bash "$script_path"
}

configure_finder_preferences() {
  local home_dir="${HOME:-}"

  if [[ -z "$home_dir" ]]; then
    log_error 'HOME is not set; cannot configure Finder preferences.'
    exit 1
  fi

  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder FXRemoveOldTrashItems -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string 'SCcf'
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
  defaults write com.apple.finder NewWindowTarget -string 'PfHm'
  defaults write com.apple.finder NewWindowTargetPath -string "file://${home_dir}/"

  killall Finder >/dev/null 2>&1 || true

  log_info 'Finder configured to show filename extensions.'
  log_info 'Finder configured to remove trash items after 30 days.'
  log_info 'Finder search configured to search the current folder.'
  log_info 'Finder configured to hide external disks on the desktop.'
  log_info 'Finder configured to hide CDs, DVDs, iPods, and removable media on the desktop.'
  log_info "Finder new windows configured to open $home_dir."
}

_apply_remote_access() {
  if ! sudo -v; then
    log_error 'Unable to acquire sudo privileges for remote access setup.'
    exit 1
  fi

  if ! sudo launchctl enable system/com.openssh.sshd >/dev/null 2>&1; then
    log_error 'Failed to enable Remote Login (SSH) service.'
    log_error 'Enable it manually in System Settings > General > Sharing > Remote Login.'
    exit 1
  fi

  sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist >/dev/null 2>&1 || true
  sudo launchctl kickstart -k system/com.openssh.sshd >/dev/null 2>&1 || true

  if ! sudo launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
    log_error 'Remote Login (SSH) could not be verified as enabled.'
    log_error 'Enable it manually in System Settings > General > Sharing > Remote Login.'
    exit 1
  fi

  if ! sudo launchctl enable system/com.apple.screensharing; then
    log_error 'Failed to enable Screen Sharing service.'
    exit 1
  fi

  sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist >/dev/null 2>&1 || true
  sudo launchctl kickstart -k system/com.apple.screensharing >/dev/null 2>&1 || true

  if ! sudo launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
    log_error 'Screen Sharing service could not be verified as loaded.'
    log_error 'Enable it manually in System Settings > General > Sharing > Screen Sharing.'
    exit 1
  fi

  log_info 'Remote Login (SSH) enabled.'
  log_info 'Screen Sharing enabled for native macOS login-window access.'
}

configure_remote_access() {
  local choice
  choice="$(interactive_select 'Enable remote access (SSH + Screen Sharing)?' 'Skip' 'Yes, enable remote access')"

  case "$choice" in
    0)
      log_info 'Skipping remote access configuration.'
      ;;
    1)
      _apply_remote_access
      ;;
  esac
}

open_full_disk_access_settings() {
  /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles' >/dev/null 2>&1 || true
  /usr/bin/osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1 || true
}

prompt_for_full_disk_access() {
  log_info 'Finder sidebar setup needs Full Disk Access for your terminal app.'
  log_info 'Enable Full Disk Access for Terminal, Ghostty, or the app running this script.'
  sleep 2
  open_full_disk_access_settings

  if [[ -t 0 ]]; then
    printf 'Press Enter after enabling Full Disk Access to retry Finder sidebar setup... '
    read -r
  fi
}

configure_finder_sidebar() {
  local home_dir="${HOME:-}"
  local code_dir
  local config_dir
  local applications_dir='/Applications'
  local desktop_dir
  local documents_dir
  local downloads_dir
  local pictures_dir
  local movies_dir
  local finder_sidebar_script="$SCRIPT_DIR/finder-sidebar.js"

  if [[ -z "$home_dir" ]]; then
    log_error 'HOME is not set; cannot configure Finder sidebar.'
    exit 1
  fi

  if [[ ! -f "$finder_sidebar_script" ]]; then
    log_error "Missing Finder sidebar script: $finder_sidebar_script"
    exit 1
  fi

  if [[ ! -x '/usr/bin/osascript' ]]; then
    log_error 'osascript is required to configure Finder sidebar favorites.'
    exit 1
  fi

  code_dir="$home_dir/code"
  config_dir="$home_dir/.config"
  desktop_dir="$home_dir/Desktop"
  documents_dir="$home_dir/Documents"
  downloads_dir="$home_dir/Downloads"
  pictures_dir="$home_dir/Pictures"
  movies_dir="$home_dir/Movies"

  mkdir -p "$code_dir"

  if ! /usr/bin/osascript -l JavaScript "$finder_sidebar_script" \
    "$home_dir" \
    "$config_dir" \
    "$code_dir" \
    "$applications_dir" \
    "$desktop_dir" \
    "$documents_dir" \
    "$downloads_dir" \
    "$pictures_dir" \
    "$movies_dir"; then
    prompt_for_full_disk_access

    if ! /usr/bin/osascript -l JavaScript "$finder_sidebar_script" \
      "$home_dir" \
      "$config_dir" \
      "$code_dir" \
      "$applications_dir" \
      "$desktop_dir" \
      "$documents_dir" \
      "$downloads_dir" \
      "$pictures_dir" \
      "$movies_dir"; then
      log_error 'Failed to configure Finder sidebar favorites.'
      log_error 'Full Disk Access may still be missing, or the terminal app may need a restart.'
      exit 1
    fi
  fi

  killall sharedfilelistd >/dev/null 2>&1 || true
  killall Finder >/dev/null 2>&1 || true

  log_info "Finder sidebar pinned: $home_dir"
  log_info "Finder sidebar pinned: $config_dir"
  log_info "Finder sidebar pinned: $code_dir"
}

first_existing_path() {
  local path

  for path in "$@"; do
    if [[ -d "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

resolve_required_app_path() {
  local app_name="$1"
  shift

  local resolved_path
  if ! resolved_path="$(first_existing_path "$@")"; then
    log_error "Unable to find ${app_name}. Checked: $*"
    exit 1
  fi

  printf '%s\n' "$resolved_path"
}

add_dock_app() {
  local app_path="$1"
  local entry

  entry="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${app_path}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
  defaults write com.apple.dock persistent-apps -array-add "$entry"
}

configure_dock() {
  local mission_control_app
  local iphone_mirroring_app
  local passwords_app
  local system_settings_app
  local activity_monitor_app
  local notes_app
  local discord_app
  local ghostty_app
  local opencode_app
  local codex_app
  local vscodium_app
  local zen_app
  local choice

  choice="$(interactive_select 'Should the Dock be visible or autohide?' 'Skip' 'Visible (always show)' 'Autohide')"

  case "$choice" in
    0)
      log_info 'Skipping Dock configuration.'
      return
      ;;
    1)
      defaults write com.apple.dock autohide -bool false
      log_info 'Dock set to always show.'
      ;;
    2)
      defaults write com.apple.dock autohide -bool true
      log_info 'Dock set to autohide.'
      ;;
  esac

  defaults write com.apple.dock tilesize -int 32
  defaults write com.apple.dock largesize -int 64
  defaults write com.apple.dock magnification -bool true

  mission_control_app="$(resolve_required_app_path 'Mission Control.app' '/System/Applications/Mission Control.app')"
  iphone_mirroring_app="$(resolve_required_app_path 'iPhone Mirroring.app' '/System/Applications/iPhone Mirroring.app')"
  passwords_app="$(resolve_required_app_path 'Passwords.app' '/System/Applications/Passwords.app')"
  system_settings_app="$(resolve_required_app_path 'System Settings.app' '/System/Applications/System Settings.app')"
  activity_monitor_app="$(resolve_required_app_path 'Activity Monitor.app' '/System/Applications/Utilities/Activity Monitor.app')"
  notes_app="$(resolve_required_app_path 'Notes.app' '/System/Applications/Notes.app' '/Applications/Notes.app')"
  discord_app="$(resolve_required_app_path 'Discord.app' '/Applications/Discord.app')"
  ghostty_app="$(resolve_required_app_path 'Ghostty.app' '/Applications/Ghostty.app')"
  opencode_app="$(resolve_required_app_path 'OpenCode.app' '/Applications/OpenCode.app')"
  codex_app="$(resolve_required_app_path 'Codex.app' '/Applications/Codex.app')"
  vscodium_app="$(resolve_required_app_path 'VSCodium.app' '/Applications/VSCodium.app')"
  zen_app="$(resolve_required_app_path 'Zen.app' '/Applications/Zen.app')"

  defaults write com.apple.dock persistent-apps -array
  add_dock_app "$mission_control_app"
  add_dock_app "$iphone_mirroring_app"
  add_dock_app "$passwords_app"
  add_dock_app "$system_settings_app"
  add_dock_app "$activity_monitor_app"
  add_dock_app "$notes_app"
  add_dock_app "$discord_app"
  add_dock_app "$ghostty_app"
  add_dock_app "$opencode_app"
  add_dock_app "$codex_app"
  add_dock_app "$vscodium_app"
  add_dock_app "$zen_app"

  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock show-recents -bool false
  killall Dock >/dev/null 2>&1 || true

  log_info 'Dock icon size set to 32 px (~25%).'
  log_info 'Dock magnification size set to 64 px (~50%).'
  log_info 'Dock updated with the requested app order, no downloads stack, and no recent apps section.'
}

set_black_wallpaper_and_screensaver() {
  local image_path

  image_path="$(create_black_background_image)"
  set_black_wallpaper "$image_path"
  set_black_screensaver "$image_path"
}

main() {
  run_step 'Set Black Wallpaper and Screen Saver' set_black_wallpaper_and_screensaver
  run_step 'Disable Handoff' disable_handoff
  run_step 'Configure Trackpad' configure_trackpad
  run_step 'Configure Keyboard Repeat' configure_keyboard_repeat
  run_step 'Install File Associations' mac_file_associations
  run_step 'Configure Finder Preferences' configure_finder_preferences
  run_step 'Configure Remote Access' configure_remote_access
  run_step 'Configure Finder Sidebar' configure_finder_sidebar
  run_step 'Configure Dock' configure_dock
}

main "$@"
