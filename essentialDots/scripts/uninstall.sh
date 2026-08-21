#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIERS_DIR="$(cd "${DOTFILES_DIR}/.." && pwd)/tiers"
# Packages moved out of this component into the repository's tier Brewfiles,
# so uninstall reads all of them. optional.Brewfile is entirely commented out
# and therefore contributes nothing, which is what keeps --pick installs
# (docker-desktop, orbstack, raycast, ...) from being swept up here.
declare -a BREWFILES=()
PIPXFILE="${DOTFILES_DIR}/Pipxfile"
STOW_TARGET="${HOME}"
STOW_PACKAGES=(zsh local git python aerospace borders btop)

assume_yes=false
dry_run=false
remove_brew=true
remove_data=true
remove_homebrew=false
remove_pipx=false

usage() {
  cat <<'EOF'
Usage: ./scripts/uninstall.sh [options]

Options:
  --yes              Do not ask for confirmation.
  --dry-run          Print what would be removed without removing anything.
  --keep-brew        Do not uninstall Brewfile formulae, casks, or taps.
  --keep-data        Do not remove generated data/cache directories.
  --pipx             Also uninstall pipx CLI apps listed in Pipxfile.
  --keep-pipx        Do not uninstall pipx CLI apps.
  --remove-homebrew  Also run Homebrew's uninstall script.
  --essential        Uninstall items from Brewfile-essential (the default).
  --full             Uninstall items from the expanded Brewfile.
  --brewfile FILE|NAME
                     Uninstall items from a specific Brewfile.
  --pipxfile FILE|NAME
                     Uninstall pipx CLI apps from a specific Pipxfile.
  -h, --help         Show this help.

By default this script:
  1. Unstows dotfile symlinks managed by this repo.
  2. Removes generated helper state created by install.sh/set-theme.
  3. Uninstalls formulae and casks listed in Brewfile.
  4. Untaps non-core taps listed in Brewfile.

It does not uninstall pipx CLI apps unless --pipx is used.
It does not remove Homebrew itself unless --remove-homebrew is used.
EOF
}

resolve_brewfile() {
  local requested="$1"

  if [[ "${requested}" = /* ]]; then
    BREWFILE="${requested}"
  else
    BREWFILE="${DOTFILES_DIR}/${requested}"
  fi
}

resolve_pipxfile() {
  local requested="$1"

  if [[ "${requested}" = /* ]]; then
    PIPXFILE="${requested}"
  else
    PIPXFILE="${DOTFILES_DIR}/${requested}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      assume_yes=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    --keep-brew)
      remove_brew=false
      ;;
    --keep-data)
      remove_data=false
      ;;
    --pipx)
      remove_pipx=true
      ;;
    --keep-pipx)
      remove_pipx=false
      ;;
    --remove-homebrew)
      remove_homebrew=true
      ;;
    --essential)
      ;;
    --full)
      ;;
    --brewfile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--brewfile requires a file path or Brewfile name." >&2
        exit 1
      fi
      resolve_brewfile "$1"
      BREWFILES=("${BREWFILE}")
      ;;
    --brewfile=*)
      resolve_brewfile "${1#*=}"
      BREWFILES=("${BREWFILE}")
      ;;
    --pipxfile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--pipxfile requires a file path or Pipxfile name." >&2
        exit 1
      fi
      remove_pipx=true
      resolve_pipxfile "$1"
      ;;
    --pipxfile=*)
      remove_pipx=true
      resolve_pipxfile "${1#*=}"
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

  cat <<EOF
This will uninstall this dotfiles setup from:
  ${DOTFILES_DIR}

It will remove stowed symlinks and uninstall Brewfile packages unless disabled.
It will uninstall pipx CLI apps only if --pipx or --pipxfile was used.
EOF

  read -r -p "Continue? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled."
      exit 1
      ;;
  esac
}

load_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

unstow_dotfiles() {
  if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is not available; skipping unstow step." >&2
    return
  fi

  run stow --dir="${DOTFILES_DIR}" --target="${STOW_TARGET}" --verbose --delete "${STOW_PACKAGES[@]}"
}

remove_path() {
  local path="$1"
  if [[ -e "${path}" || -L "${path}" ]]; then
    run rm -rf "${path}"
  fi
}

remove_git_checkout() {
  local path="$1"
  local expected_origin="$2"
  local origin

  [[ -d "${path}/.git" ]] || return 0

  origin="$(git -C "${path}" config --get remote.origin.url || true)"
  case "${origin}" in
    "${expected_origin}"|"${expected_origin}.git")
      remove_path "${path}"
      ;;
    *)
      echo "Skipping ${path}; Git origin does not match ${expected_origin}." >&2
      ;;
  esac
}

remove_generated_data() {
  [[ "${remove_data}" == true ]] || return 0

  remove_git_checkout "${HOME}/.config/oh-my-zsh" "https://github.com/ohmyzsh/ohmyzsh"
  remove_path "${HOME}/.config/zsh/apps/themerc"
  remove_path "${HOME}/.config/.pyenv"
  remove_path "${HOME}/.config/nvm"
  # The recorded stow roots moved to a shared, repository-wide state
  # directory when stale-symlink migration became shared by every component.
  # The old per-component path is still removed so an upgrade leaves nothing
  # behind.
  remove_path "${XDG_STATE_HOME:-${HOME}/.local/state}/essentialDots/stow-root"
  remove_path "${XDG_STATE_HOME:-${HOME}/.local/state}/intelliDots/stow-roots"

  run rmdir "${XDG_STATE_HOME:-${HOME}/.local/state}/essentialDots" 2>/dev/null || true
  run rmdir "${XDG_STATE_HOME:-${HOME}/.local/state}/intelliDots" 2>/dev/null || true
}

read_brewfile_items() {
  local kind="$1"
  sed -nE "s/^[[:space:]]*${kind} \"([^\"]+)\".*/\1/p" "${BREWFILES[@]}" | sort -u
}

uninstall_brew_items() {
  [[ "${remove_brew}" == true ]] || return 0

  if [[ "${#BREWFILES[@]}" -eq 0 ]]; then
    BREWFILES=("${TIERS_DIR}"/*.Brewfile)
  fi
  if [[ ! -f "${BREWFILES[0]}" ]]; then
    echo "No tier Brewfiles found under ${TIERS_DIR}" >&2
    exit 1
  fi

  load_homebrew
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not available; skipping Brewfile uninstall step." >&2
    return
  fi

  while IFS= read -r cask; do
    [[ -n "${cask}" ]] || continue
    if brew list --cask "${cask}" >/dev/null 2>&1; then
      run brew uninstall --cask --zap "${cask}" || run brew uninstall --cask "${cask}"
    fi
  done < <(read_brewfile_items cask)

  while IFS= read -r formula; do
    [[ -n "${formula}" ]] || continue
    if brew list --formula "${formula}" >/dev/null 2>&1; then
      run brew uninstall --formula --ignore-dependencies "${formula}"
    fi
  done < <(read_brewfile_items brew)

  run brew autoremove
  run brew cleanup

  while IFS= read -r tap; do
    [[ -n "${tap}" ]] || continue
    if brew tap | command grep -qx "${tap}"; then
      run brew untrust --tap "${tap}" || true
      run brew untap "${tap}"
    fi
  done < <(read_brewfile_items tap)
}

uninstall_homebrew() {
  [[ "${remove_homebrew}" == true ]] || return 0

  if [[ "${dry_run}" == true ]]; then
    echo "DRY RUN: would run Homebrew uninstall script"
    return
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
}

uninstall_pipx_items() {
  [[ "${remove_pipx}" == true ]] || return 0

  if [[ "${dry_run}" == true ]]; then
    "${SCRIPT_DIR}/uninstall-pipx.sh" --pipxfile "${PIPXFILE}" --dry-run
    return
  fi

  "${SCRIPT_DIR}/uninstall-pipx.sh" --pipxfile "${PIPXFILE}"
}

confirm
unstow_dotfiles
remove_generated_data
uninstall_pipx_items
uninstall_brew_items
uninstall_homebrew

echo "Uninstall complete."
