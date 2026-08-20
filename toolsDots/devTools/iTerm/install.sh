#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${PROJECT_DIR}" --target="${HOME}" --verbose --restow --no-folding)
run_brew=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--adopt] [--dry-run]

Installs iTerm2's profile assets and points the app at them. Packages are no
longer declared here -- iterm2 and its font live in the repository's tier
Brewfiles under tiers/, installed once by the root install.sh.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    # Profile flags are accepted so the root installer can pass them uniformly,
    # but they no longer select a Brewfile: packages come from tiers/.
    --essential) ;;
    --full) ;;
    --no-brew) run_brew=false ;;
    --adopt) STOW_FLAGS+=(--adopt) ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

if [[ "${dry_run}" == true ]]; then
  stow "${STOW_FLAGS[@]}" --simulate iterm2 || true
  echo "Would configure iTerm2 to load preferences from ${XDG_CONFIG_HOME}/iterm2"
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  echo "Note: this component no longer installs its own packages." >&2
  echo "      Run the repository's root install.sh to install from tiers/." >&2
fi

command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
mkdir -p "${XDG_CONFIG_HOME}/iterm2"
stow "${STOW_FLAGS[@]}" iterm2
# Point the app itself at the stowed prefs folder instead of its default
# sandboxed plist location, so the tracked files are what actually load.
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "${XDG_CONFIG_HOME}/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

echo "iTerm installed. Restart iTerm2 to load the tracked preferences."
echo "Legacy importable profiles are under ${PROJECT_DIR}/assets/legacy."
