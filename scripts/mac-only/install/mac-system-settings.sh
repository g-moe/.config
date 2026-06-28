#!/usr/bin/env bash
set -euo pipefail

# Conventions
#  - Keep app/service restarts centralized in finish() so interactive or skipped steps cannot leave later settings unapplied.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/interactive.sh"
. "$LIB_DIR/utils.sh"



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

  defaults -currentHost write com.apple.screensaver idleTime -int 0

  log_info 'Screen saver configured to use black image folder.'
}

disable_handoff() {
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false

  log_info 'Handoff disabled.'
}

configure_trackpad() {
  # Tracking speed: 3 is the fastest setting in macOS
  defaults write -g com.apple.trackpad.scaling -float 3

  # Built-in trackpad settings
  defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
  defaults write com.apple.AppleMultitouchTrackpad ActuationEnabled -bool false
  defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool true
  defaults write com.apple.AppleMultitouchTrackpad ActuateDetents -bool false
  defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
  defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.AppleMultitouchTrackpad TrackpadScroll -bool false
  defaults write com.apple.AppleMultitouchTrackpad TrackpadPinch -bool false
  defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -bool false
  defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -bool false
  defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
  defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 0
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0

  # External Magic Trackpad settings
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad FirstClickThreshold -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ActuationEnabled -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ForceSuppressed -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ActuateDetents -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadScroll -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadPinch -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerDoubleTapGesture -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRotate -bool false
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 0
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0

  # Global gesture settings
  defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # Gesture on/off toggles are handled by Dock settings
  defaults write com.apple.dock showMissionControlGestureEnabled -bool true
  defaults write com.apple.dock showAppExposeGestureEnabled -bool false
  defaults write com.apple.dock showDesktopGestureEnabled -bool false

  # Apply trackpad settings immediately
  if [[ -x /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings ]]; then
    silent /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  fi

  log_info 'Trackpad tracking speed set to fastest (3).'
  log_info 'Trackpad click set to light.'
  log_info 'Trackpad quiet click disabled.'
  log_info 'Trackpad force click and haptic feedback disabled.'
  log_info 'Trackpad look up and data detectors disabled.'
  log_info 'Trackpad secondary click set to two fingers.'
  log_info 'Trackpad tap to click enabled.'
  log_info 'Natural scrolling disabled.'
  log_info 'Pinch to zoom disabled.'
  log_info 'Smart zoom disabled.'
  log_info 'Rotate gesture disabled.'
  log_info 'Swipe between pages disabled.'
  log_info 'Swipe between full-screen apps set to three fingers.'
  log_info 'Notification Center swipe disabled.'
  log_info 'Mission Control set to four-finger swipe up.'
  log_info 'App Expose gesture disabled.'
  log_info 'Show desktop gesture disabled.'
}

configure_keyboard_repeat() {
  defaults write NSGlobalDomain KeyRepeat -int 120
  defaults write NSGlobalDomain InitialKeyRepeat -int 25

  log_info 'Key repeat rate set to slow (120 ms).'
  log_info 'Delay until repeat set to shortest (225 ms).'
}

configure_theme() {
  defaults write NSGlobalDomain AppleAccentColor -int 4
  defaults write NSGlobalDomain AppleHighlightColor -string '0.698039 0.843137 1.000000 Blue'
  defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
  defaults write NSGlobalDomain AppleIconAppearanceTheme -string TintedDark
  defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Other
  defaults write NSGlobalDomain AppleIconAppearanceCustomTintColor -string '0.596078 0.596078 0.615686 0.250000'

  log_info 'Theme color set to blue.'
  log_info 'Text highlight color set to blue.'
  log_info 'Appearance set to dark.'
  log_info 'Icon and widget style set to tinted dark.'
  log_info 'Icon, widget, and folder color set to custom gray.'
}

configure_mission_control() {
  defaults write com.apple.dock mru-spaces -bool false
  defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool false
  defaults write com.apple.dock workspaces-auto-swoosh -bool false
  defaults write com.apple.dock expose-group-apps -bool false
  defaults write com.apple.spaces spans-displays -bool true
  defaults write com.apple.dock enterMissionControlByTopWindowDrag -bool false

  log_info 'Spaces are not automatically rearranged based on recent use.'
  log_info 'Switching apps does not switch to an app window Space.'
  log_info 'Mission Control does not group windows by application.'
  log_info 'Displays do not have separate Spaces.'
  log_info 'Dragging windows to the top of the screen does not enter Mission Control.'
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
  defaults write com.apple.finder FXPreferredViewStyle -string 'clmv'

  log_info 'Finder configured to show filename extensions.'
  log_info 'Finder configured to remove trash items after 30 days.'
  log_info 'Finder search configured to search the current folder.'
  log_info 'Finder configured to hide external disks on the desktop.'
  log_info 'Finder configured to hide CDs, DVDs, iPods, and removable media on the desktop.'
  log_info "Finder new windows configured to open $home_dir."
  log_info 'Finder default view configured to column view.'
}

_apply_remote_access() {
  if ! sudo -v; then
    log_error 'Unable to acquire sudo privileges for remote access setup.'
    exit 1
  fi

  # SSH (Remote Login)
  if ! silent sudo launchctl enable system/com.openssh.sshd; then
    log_error 'Failed to enable Remote Login (SSH) service.'
    log_error 'Enable it manually in System Settings > General > Sharing > Remote Login.'
    exit 1
  fi

  silent sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist || true

  if ! silent sudo launchctl print system/com.openssh.sshd; then
    log_error 'Remote Login (SSH) could not be verified as enabled.'
    log_error 'Enable it manually in System Settings > General > Sharing > Remote Login.'
    exit 1
  fi

  # Screen Sharing
  if ! silent sudo launchctl enable system/com.apple.screensharing; then
    log_error 'Failed to enable Screen Sharing service.'
    exit 1
  fi

  silent sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist || true

  if ! silent sudo launchctl print system/com.apple.screensharing; then
    log_error 'Screen Sharing service could not be verified as loaded.'
    log_error 'Enable it manually in System Settings > General > Sharing > Screen Sharing.'
    exit 1
  fi

  log_info 'Remote Login (SSH) enabled.'
  log_info 'Screen Sharing enabled for native macOS login-window access.'
}

configure_headless_access() {
  local filevault_status

  filevault_status="$(fdesetup status 2>/dev/null || echo 'unknown')"

  log_info 'Headless remote access (Screen Sharing after reboot without local login)'
  log_info 'requires FileVault to be OFF.'

  if [[ "$filevault_status" == *"FileVault is On."* ]]; then
    log_info 'FileVault is currently ON.'
    log_info 'With FileVault enabled, macOS cannot start network services after a reboot'
    log_info 'until someone physically enters the password at the pre-boot unlock screen.'

    local choice
    choice="$(interactive_select 'Disable FileVault to allow remote Screen Sharing after reboot?' 'Skip (keep FileVault on)' 'Yes, disable FileVault')"

    case "$choice" in
      1)
        if ! sudo -v; then
          log_error 'Unable to acquire sudo privileges to disable FileVault.'
          return
        fi
        log_info 'Disabling FileVault. Decryption will run in the background; you can keep using your Mac.'
        if sudo fdesetup disable; then
          log_info 'FileVault disable initiated. Do not turn FileVault back on until decryption is complete.'
          log_info 'You can check progress in System Settings > Privacy & Security > FileVault.'
        else
          log_error 'Failed to disable FileVault.'
          log_error 'Please disable it manually: System Settings > Privacy & Security > FileVault.'
          return
        fi
        ;;
      *)
        log_info 'Keeping FileVault ON. Screen Sharing will require a local login after each reboot.'
        log_info 'Tip: use `sudo fdesetup authrestart` instead of a normal reboot to skip the unlock screen once.'
        return
        ;;
    esac
  else
    log_info 'FileVault is already off.'
  fi
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
  silent /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles' || true
  silent /usr/bin/osascript -e 'tell application "System Settings" to activate' || true
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
  local ghostty_app
  local opencode_app
  local codex_app
  local vscodium_app
  local dock_hiding_choice
  local dock_hiding_message='Dock hiding preference left unchanged.'

  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock mineffect -string scale
  defaults write com.apple.dock minimize-to-application -bool false

  dock_hiding_choice="$(interactive_select 'Choose Dock hiding behavior:' 'Skip (leave current setting)' 'Automatically hide and show the Dock' 'Always show the Dock')"
  case "$dock_hiding_choice" in
    1)
      defaults write com.apple.dock autohide -bool true
      dock_hiding_message='Dock configured to autohide.'
      ;;
    2)
      defaults write com.apple.dock autohide -bool false
      dock_hiding_message='Dock configured to always show.'
      ;;
  esac

  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock show-process-indicators -bool true
  defaults write com.apple.dock show-recents -bool false

  defaults write NSGlobalDomain AppleActionOnDoubleClick -string Maximize

  defaults write com.apple.dock tilesize -int 32
  defaults write com.apple.dock largesize -int 64
  defaults write com.apple.dock magnification -bool true

  mission_control_app="$(resolve_required_app_path 'Mission Control.app' '/System/Applications/Mission Control.app')"
  iphone_mirroring_app="$(resolve_required_app_path 'iPhone Mirroring.app' '/System/Applications/iPhone Mirroring.app')"
  passwords_app="$(resolve_required_app_path 'Passwords.app' '/System/Applications/Passwords.app')"
  system_settings_app="$(resolve_required_app_path 'System Settings.app' '/System/Applications/System Settings.app')"
  activity_monitor_app="$(resolve_required_app_path 'Activity Monitor.app' '/System/Applications/Utilities/Activity Monitor.app')"
  notes_app="$(resolve_required_app_path 'Notes.app' '/System/Applications/Notes.app' '/Applications/Notes.app')"
  ghostty_app="$(resolve_required_app_path 'Ghostty.app' '/Applications/Ghostty.app')"
  opencode_app="$(resolve_required_app_path 'OpenCode.app' '/Applications/OpenCode.app')"
  codex_app="$(resolve_required_app_path 'Codex.app' '/Applications/Codex.app')"
  vscodium_app="$(resolve_required_app_path 'VSCodium.app' '/Applications/VSCodium.app')"

  defaults write com.apple.dock persistent-apps -array
  add_dock_app "$mission_control_app"
  add_dock_app "$iphone_mirroring_app"
  add_dock_app "$passwords_app"
  add_dock_app "$system_settings_app"
  add_dock_app "$activity_monitor_app"
  add_dock_app "$notes_app"
  add_dock_app "$ghostty_app"
  add_dock_app "$opencode_app"
  add_dock_app "$codex_app"
  add_dock_app "$vscodium_app"

  defaults write com.apple.dock persistent-others -array

  log_info 'Dock position set to bottom.'
  log_info 'Dock minimize effect set to scale.'
  log_info 'Window title bar double-click set to maximize/fill.'
  log_info 'Dock configured to not minimize windows into application icons.'
  log_info "$dock_hiding_message"
  log_info 'Dock application launch animation disabled.'
  log_info 'Dock open application indicators enabled.'
  log_info 'Dock recents section disabled.'
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

desktopAndStageManager() {
  defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
  defaults write com.apple.WindowManager HideDesktop -bool true
  defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
  defaults write com.apple.WindowManager GloballyEnabled -bool false
  defaults write com.apple.WindowManager AutoHide -bool true
  defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1

  log_info 'Desktop items hidden.'
  log_info 'Click wallpaper to show desktop set to only in Stage Manager.'
  log_info 'Stage Manager disabled.'
  log_info 'Recent apps hidden in Stage Manager.'
  log_info 'Stage Manager app windows shown all at once.'
}

widgets() {
  defaults write com.apple.WindowManager StandardHideWidgets -bool true
  defaults write com.apple.WindowManager StageManagerHideWidgets -bool true

  log_info 'Widgets hidden on desktop.'
  log_info 'Widgets hidden in Stage Manager.'
  log_info 'Desktop widget dimming left at automatic.'
}

configure_window_tiling() {
  defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

  log_info 'Window tiling by screen-edge drag disabled.'
  log_info 'Window fill by menu-bar drag disabled.'
  log_info 'Option-key window tiling while dragging disabled.'
  log_info 'Tiled window margins disabled.'
}

configure_software_updates() {
  if ! sudo -v; then
    log_error 'Unable to acquire sudo privileges for software update setup.'
    return
  fi

  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool false
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool false
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool false
  sudo defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdate -bool false

  log_info 'Software updates configured to download only (not auto-install).'
}

disable_apple_intelligence() {
  defaults write com.apple.Siri AppleIntelligenceEnabled -bool false
  defaults write com.apple.Siri LLMEnable -bool false

  log_info 'Apple Intelligence disabled.'
}

disable_siri() {
  defaults write com.apple.assistant.support 'Assistant Enabled' -bool false
  defaults write com.apple.Siri StatusMenuVisible -bool false
  defaults write com.apple.Siri UserHasDeclinedEnable -bool true
  defaults write com.apple.assistant.support 'Siri Data Sharing Opt-In Status' -int 2
  defaults write com.apple.SetupAssistant 'DidSeeSiriSetup' -bool true

  log_info 'Siri disabled.'
  log_info 'Siri menu bar icon hidden.'
  log_info 'Siri setup prompt suppressed.'
  log_info 'Siri data sharing opted out.'
}

configure_control_center() {
  # Module visibility in Control Center / Menu Bar (ByHost plist)
  defaults -currentHost write com.apple.controlcenter Battery -int 8
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -int 0
  defaults -currentHost write com.apple.controlcenter Bluetooth -int 24
  defaults -currentHost write com.apple.controlcenter Display -int 8
  defaults -currentHost write com.apple.controlcenter FocusModes -int 8
  defaults -currentHost write com.apple.controlcenter KeyboardBrightness -int 8
  defaults -currentHost write com.apple.controlcenter NowPlaying -int 8
  defaults -currentHost write com.apple.controlcenter ScreenMirroring -int 8
  defaults -currentHost write com.apple.controlcenter Sound -int 8
  defaults -currentHost write com.apple.controlcenter TimeMachine -int 8
  defaults -currentHost write com.apple.controlcenter VoiceControl -int 8
  defaults -currentHost write com.apple.controlcenter WiFi -int 8

  # NSStatusItem visibility in menu bar (main plist)
  defaults write com.apple.controlcenter "NSStatusItem Visible AirDrop" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible FaceTime" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-0" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-1" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-2" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-3" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-4" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-5" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-6" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-7" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-8" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Item-9" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible ScreenMirroring" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Shortcuts" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool false
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC BentoBox-0" -bool true
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC Clock" -bool true

  # Hide Spotlight search icon from menu bar
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

  log_info 'Control Center configured to hide most system icons from menu bar.'
  log_info 'Weather widget (BentoBox) enabled in menu bar.'
  log_info 'Battery percentage hidden.'
  log_info 'Spotlight icon hidden from menu bar.'
}

configure_menu_bar() {
  defaults write com.apple.controlcenter AutoHideMenuBarOption -int 3
  defaults write NSGlobalDomain _HIHideMenuBar -bool false
  defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool true
  defaults write NSGlobalDomain NSRecentDocumentsLimit -int 0

  # 'Show menu bar background' is a newer macOS setting (Tahoe 26+) and its
  # exact defaults key is not yet documented for command-line use.
  # The legacy key below may not have an effect on newer releases.
  silent defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool true || true

  # Menu bar clock format: "May 31 21:29:18"
  defaults write com.apple.menuextra.clock DateFormat -string "MMM d HH:mm:ss"
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock Show24Hour -bool true
  defaults write com.apple.menuextra.clock ShowSeconds -bool true
  defaults write com.apple.menuextra.clock ShowAMPM -bool false
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
  defaults write com.apple.menuextra.clock ShowDayOfMonth -bool true
  defaults write com.apple.menuextra.clock ShowDate -int 0

  log_info 'Menu bar configured to never hide.'
  log_info 'Menu bar background configured with the legacy transparency key.'
  log_info 'Recent documents, applications, and servers set to none.'
  log_info 'Menu bar clock format set to "May 31 21:29:18".'
  log_info 'Note: macOS menu bar clock does not support timezone display in the format string.'
}

finish() {
  silent killall useractivityd || true
  silent killall sharedfilelistd || true
  silent killall Finder || true
  silent killall Dock || true
  silent killall Siri || true
  silent killall Spotlight || true
  silent killall ControlCenter || true
  silent killall SystemUIServer || true

  log_info 'Restarted macOS services affected by system settings.'
}

main() {
  run_step 'Set Black Wallpaper and Screen Saver' set_black_wallpaper_and_screensaver
  run_step 'Disable Handoff' disable_handoff
  run_step 'Disable Apple Intelligence' disable_apple_intelligence
  run_step 'Disable Siri' disable_siri
  run_step 'Configure Trackpad' configure_trackpad
  run_step 'Configure Keyboard Repeat' configure_keyboard_repeat
  run_step 'Configure Theme' configure_theme
  run_step 'Configure Mission Control' configure_mission_control
  run_step 'Install File Associations' mac_file_associations
  run_step 'Configure Finder Preferences' configure_finder_preferences
  run_step 'Configure Headless Remote Access' configure_headless_access
  run_step 'Configure Remote Access' configure_remote_access
  run_step 'Configure Finder Sidebar' configure_finder_sidebar
  run_step 'Configure Desktop and Stage Manager' desktopAndStageManager
  run_step 'Configure Widgets' widgets
  run_step 'Configure Window Tiling' configure_window_tiling
  run_step 'Configure Dock' configure_dock
  run_step 'Configure Software Updates' configure_software_updates
  run_step 'Configure Control Center' configure_control_center
  run_step 'Configure Menu Bar' configure_menu_bar
  run_step 'Apply System Setting Restarts' finish
}

main "$@"
