#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Arc Main Window
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/Arc.app/Contents/Resources/AppIcon.icns
# @raycast.packageName Window Tools

set -euo pipefail

STATE_FILE="${TMPDIR:-/tmp}/raycast-toggle-arc-main-window.state"

main_bounds="$(osascript -l JavaScript <<'JXA'
ObjC.import("AppKit");

const frame = $.NSScreen.mainScreen.frame;
[
  Math.round(frame.origin.x),
  Math.round(frame.origin.y),
  Math.round(frame.size.width),
  Math.round(frame.size.height),
].join(",");
JXA
)"

IFS=, read -r main_x main_y main_width main_height <<<"$main_bounds"

last_state="hidden"
last_window_name=""
if [[ -f "$STATE_FILE" ]]; then
  last_state="$(sed -n '1p' "$STATE_FILE")"
  last_window_name="$(sed -n '2p' "$STATE_FILE")"
fi

next_state="$(
  osascript - "$main_x" "$main_y" "$main_width" "$main_height" "$last_state" "$last_window_name" <<'APPLESCRIPT'
on run argv
  set mainX to item 1 of argv as integer
  set mainY to item 2 of argv as integer
  set mainWidth to item 3 of argv as integer
  set mainHeight to item 4 of argv as integer
  set lastState to item 5 of argv
  set lastWindowName to item 6 of argv
  set mainRight to mainX + mainWidth
  set mainBottom to mainY + mainHeight

  tell application "System Events"
    if not (exists process "Arc") then
      tell application "Arc" to launch
      repeat 30 times
        if exists process "Arc" then exit repeat
        delay 0.01
      end repeat
    end if

    tell process "Arc"
      set candidateWindow to missing value

      if lastState is "hidden" then
        set minimizedFallbackWindow to missing value

        repeat with arcWindow in windows
          if value of attribute "AXMinimized" of arcWindow is true then
            if minimizedFallbackWindow is missing value then set minimizedFallbackWindow to arcWindow

            if lastWindowName is not "" and name of arcWindow is lastWindowName then
              set value of attribute "AXMinimized" of arcWindow to false
              set frontmost to true
              perform action "AXRaise" of arcWindow
              try
                set value of attribute "AXMain" of arcWindow to true
              end try
              try
                set value of attribute "AXFocusedWindow" of process "Arc" to arcWindow
              end try
              set focused of arcWindow to true
              return "shown" & linefeed & (name of arcWindow)
            end if
          end if
        end repeat

        if minimizedFallbackWindow is not missing value then
          set value of attribute "AXMinimized" of minimizedFallbackWindow to false
          set frontmost to true
          perform action "AXRaise" of minimizedFallbackWindow
          try
            set value of attribute "AXMain" of minimizedFallbackWindow to true
          end try
          try
            set value of attribute "AXFocusedWindow" of process "Arc" to minimizedFallbackWindow
          end try
          set focused of minimizedFallbackWindow to true
          return "shown" & linefeed & (name of minimizedFallbackWindow)
        end if
      end if

      repeat with arcWindow in windows
        if value of attribute "AXMinimized" of arcWindow is false then
          set windowPosition to position of arcWindow
          set windowSize to size of arcWindow
          set windowCenterX to (item 1 of windowPosition) + ((item 1 of windowSize) / 2)
          set windowCenterY to (item 2 of windowPosition) + ((item 2 of windowSize) / 2)

          if windowCenterX >= mainX and windowCenterX < mainRight and windowCenterY >= mainY and windowCenterY < mainBottom then
            set candidateWindow to arcWindow
            exit repeat
          end if
        end if
      end repeat

      if candidateWindow is not missing value then
        if lastState is "shown" then
          set candidateWindowName to name of candidateWindow
          set value of attribute "AXMinimized" of candidateWindow to true
          return "hidden" & linefeed & candidateWindowName
        else
          set frontmost to true
          perform action "AXRaise" of candidateWindow
          try
            set value of attribute "AXMain" of candidateWindow to true
          end try
          try
            set value of attribute "AXFocusedWindow" of process "Arc" to candidateWindow
          end try
          set focused of candidateWindow to true
          return "shown" & linefeed & (name of candidateWindow)
        end if
      end if
    end tell
  end tell

  return "hidden" & linefeed & ""
end run
APPLESCRIPT
)"

printf '%s\n' "$next_state" >"$STATE_FILE"
