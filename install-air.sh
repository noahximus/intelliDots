#!/usr/bin/env bash
set -euo pipefail

# One command to install, or re-install, this configuration on a Mac.
#
# The difference from bootstrap.sh: no GitHub authentication (the repository
# is public, so a plain git clone is enough), and the macOS defaults can be
# declined. Short enough to type by hand when a long curl keeps arriving
# mangled, and safe to re-run.
#
# Prerequisites are not assumed. Apple's command-line tools are checked for
# and offered; Homebrew is left to install.sh, which installs it when missing.
#
#   ./install-air.sh                       # air-plus, applying macOS defaults
#   ./install-air.sh --no-macos-defaults   # leave System Settings alone
#   ./install-air.sh --profile air --dry-run
#
# Works from inside a checkout or standalone: without one it clones to
# ~/.config/intelliDots, with one it fast-forwards it.

REPO_URL="https://github.com/noahximus/intelliDots.git"
CHECKOUT="${INTELLIDOTS_ROOT:-${HOME}/.config/intelliDots}"
profile="air-plus"
macos_defaults=true
declare -a extra=()

usage() {
  cat <<'EOF'
Usage: ./install-air.sh [--profile NAME] [--no-macos-defaults] [--dry-run]

Options:
  --profile NAME        Profile to install. Default: air-plus
  --no-macos-defaults   Do not apply the personal macOS System Settings.
                         Worth using on a Mac that is not yours to configure,
                         and on a first run while you set Stats up.
  --dry-run             Show what would happen, change nothing.
  -h, --help            Show this help.

Environment:
  INTELLIDOTS_ROOT  Checkout location. Default: ~/.config/intelliDots
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) shift; [[ $# -gt 0 ]] || { echo "--profile requires a name" >&2; exit 2; }; profile="$1" ;;
    --profile=*) profile="${1#*=}" ;;
    --no-macos-defaults) macos_defaults=false ;;
    --dry-run) extra+=(--dry-run) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# Not `command -v git`: /usr/bin/git exists on every Mac as a stub that pops
# the developer-tools installer instead of running, so that check always
# passes and proves nothing. xcode-select -p is the real test.
#
# Homebrew is deliberately not checked. install.sh installs it when missing,
# so the only prerequisite this script needs on its own is a git that works.
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple's command-line tools are required for git."
  echo "Complete the installer that opens, then run this script again."
  # Apple's installer runs asynchronously, so this always exits non-zero and
  # the caller reruns once it finishes.
  xcode-select --install 2>/dev/null || true
  exit 1
fi

if [[ -d "${CHECKOUT}/.git" ]]; then
  # Refuse to pull over local edits rather than failing halfway with a merge
  # conflict in a directory the user is not expecting to be a working tree.
  if [[ -n "$(git -C "${CHECKOUT}" status --porcelain)" ]]; then
    echo "Checkout has local changes; not pulling: ${CHECKOUT}" >&2
    echo "Commit or discard them, then rerun." >&2
    exit 1
  fi
  echo "==> Updating ${CHECKOUT}"
  git -C "${CHECKOUT}" pull --ff-only
else
  echo "==> Cloning into ${CHECKOUT}"
  git clone "${REPO_URL}" "${CHECKOUT}"
fi

# Symlinks left by a checkout at a different path are relinked by each
# component before it stows, so an earlier install under ~/Developer is
# migrated rather than colliding. Say so, since it is the one thing that
# looks alarming in the output.
if [[ -d "${HOME}/Developer/myConfigs/intelliDots" && "${CHECKOUT}" != "${HOME}/Developer/myConfigs/intelliDots" ]]; then
  echo "==> An older checkout exists at ~/Developer/myConfigs/intelliDots."
  echo "    Its symlinks will be migrated to ${CHECKOUT} automatically;"
  echo "    'Migrating stale symlink' lines below are expected."
fi

[[ "${macos_defaults}" == true ]] && extra+=(--macos-defaults) || extra+=(--no-macos-defaults)

echo "==> install.sh --profile ${profile} ${extra[*]}"
exec "${CHECKOUT}/install.sh" --profile "${profile}" "${extra[@]}"
