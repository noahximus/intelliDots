#!/usr/bin/env bash

set -euo pipefail

assume_yes=false
dry_run=false
restart_apps=true

usage() {
  cat <<'EOF'
Usage: ./scripts/macos-defaults.sh [options]

Options:
  --yes          Apply settings without asking for confirmation.
  --dry-run      Print the settings that would be applied.
  --no-restart   Do not restart Finder, Dock, or SystemUIServer.
  -h, --help     Show this help.

This script applies personal macOS settings that are usually changed through
System Settings, Finder settings, Dock settings, and Screenshot settings.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      assume_yes=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    --no-restart)
      restart_apps=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

run() {
  if [[ "${dry_run}" == true ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
    return
  fi

  "$@"
}

confirm() {
  if [[ "${assume_yes}" == true || "${dry_run}" == true ]]; then
    return
  fi

  cat <<'EOF'
This will apply your personal macOS UI preferences:

  - Dark Mode, fast key repeat, and show filename extensions.
  - Dock auto-hide, magnification, size, and hot corners.
  - Finder path bar, folder sorting, desktop drive visibility, and search scope.
  - Trackpad tap-to-click and gesture preferences.
  - Screenshot save location.
  - Menu bar / Control Center visibility preferences.
  - TG Pro monitoring with macOS retaining fan control.

EOF

  read -r -p "Apply these macOS settings? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled."
      exit 1
      ;;
  esac
}

restart_changed_apps() {
  [[ "${restart_apps}" == true ]] || return

  run killall Finder 2>/dev/null || true
  run killall Dock 2>/dev/null || true
  run killall SystemUIServer 2>/dev/null || true
}

confirm

# General appearance and behavior.
run defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
run defaults write NSGlobalDomain AppleLanguages -array "en-PH" "fil-PH"
run defaults write NSGlobalDomain AppleLocale -string "en_PH"
run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run defaults write NSGlobalDomain InitialKeyRepeat -int 15
run defaults write NSGlobalDomain KeyRepeat -int 2
run defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
run defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool true
run defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool true
run defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true

# Trackpad and mouse preferences.
run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -bool false
run defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool false
run defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
run defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -int 1
run defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
run defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2
run defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
run defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 2
run defaults write com.apple.AppleMultitouchTrackpad TrackpadPinch -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadScroll -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadHorizScroll -bool true
run defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true
run defaults write NSGlobalDomain com.apple.mouse.scaling -float 1

# Mirror the built-in trackpad preferences for Bluetooth Magic Trackpad.
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -bool false
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool false
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerDoubleTapGesture -int 1
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 2

# Dock preferences.
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock magnification -bool true
run defaults write com.apple.dock tilesize -int 36
run defaults write com.apple.dock largesize -int 73
run defaults write com.apple.dock minimize-to-application -bool true
run defaults write com.apple.dock expose-group-apps -bool true
run defaults write com.apple.dock wvous-tr-corner -int 12
run defaults write com.apple.dock wvous-tr-modifier -int 0
run defaults write com.apple.dock wvous-br-corner -int 4
run defaults write com.apple.dock wvous-br-modifier -int 0

# Finder preferences.
run defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
run defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
run defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder ShowSidebar -bool true
run defaults write com.apple.finder ShowStatusBar -bool false
run defaults write com.apple.finder _FXSortFoldersFirst -bool true
run defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true
run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Screenshots.
run mkdir -p "${HOME}/Desktop/screenshots"
run defaults write com.apple.screencapture location -string "${HOME}/Desktop/screenshots"
run defaults write com.apple.screencapture target -string "file"
run defaults write com.apple.screencapture type -string "png"

# Menu bar and Control Center visibility.
run defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible Display" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible Shortcuts" -bool true
run defaults write com.apple.controlcenter "NSStatusItem Visible ScreenMirroring" -bool false
run defaults write com.apple.controlcenter "NSStatusItem Visible KeyboardBrightness" -bool false

# TG Pro: monitor the highest CPU temperature while macOS controls the fans.
# These are documented deployment keys; no license or machine-specific data is stored.
tg_pro_domain="com.tunabellysoftware.tgpro"
run defaults write "${tg_pro_domain}" launchOnLogin -bool true
run defaults write "${tg_pro_domain}" automaticallyCheckForUpdates -bool true
run defaults write "${tg_pro_domain}" fanControlType -int 0
run defaults write "${tg_pro_domain}" useManualInsteadOfMax -bool false
run defaults write "${tg_pro_domain}" useAutoBoostInsteadOfAutoMax -bool false
run defaults write "${tg_pro_domain}" enableSystemOverrides -array -bool false
run defaults write "${tg_pro_domain}" showTempInMenuBar -bool true
run defaults write "${tg_pro_domain}" menuBarTempSensorIndex -int 4
run defaults write "${tg_pro_domain}" showTemp2InMenuBar -bool false
run defaults write "${tg_pro_domain}" tempUnit -int 0
run defaults write "${tg_pro_domain}" logToFile -bool false

restart_changed_apps

echo "macOS defaults applied."
