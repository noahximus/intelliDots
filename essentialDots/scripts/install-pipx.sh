#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/progress.sh
. "${SCRIPT_DIR}/lib/progress.sh"
trap 'ui_fail "pipx application installation failed"' ERR
PIPXFILE="${DOTFILES_DIR}/Pipxfile"
UPGRADE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/install-pipx.sh [--pipxfile FILE|NAME] [--upgrade]

Options:
  --pipxfile FILE|NAME Install packages from a specific Pipxfile.
                        Relative names are resolved from this dotfiles directory.
  --upgrade            Upgrade already-installed pipx packages listed in the file.
  -h, --help           Show this help.

Pipxfile format:
  package-name
  package-name # optional comment

Blank lines and comments are ignored.
EOF
}

resolve_pipxfile() {
  local requested="$1"

  if [[ "${requested}" = /* ]]; then
    PIPXFILE="${requested}"
  else
    PIPXFILE="${DOTFILES_DIR}/${requested}"
  fi
}

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

read_pipx_packages() {
  local raw line

  while IFS= read -r raw || [[ -n "${raw}" ]]; do
    line="${raw%%#*}"
    line="$(trim "${line}")"

    [[ -n "${line}" ]] || continue
    printf '%s\n' "${line}"
  done < "${PIPXFILE}"
}

pipx_package_installed() {
  local package="$1"

  pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fxq "${package}"
}

install_pipx_package() {
  local package="$1"

  if pipx_package_installed "${package}"; then
    if [[ "${UPGRADE}" == true ]]; then
      ui_info "Upgrading installed package"
      pipx upgrade "${package}"
    else
      ui_skip "Already installed"
    fi
    return
  fi

  ui_info "Installing missing package"
  pipx install "${package}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipxfile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--pipxfile requires a file path or Pipxfile name." >&2
        exit 1
      fi
      resolve_pipxfile "$1"
      ;;
    --pipxfile=*)
      resolve_pipxfile "${1#*=}"
      ;;
    --upgrade)
      UPGRADE=true
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

if ! command -v pipx >/dev/null 2>&1; then
  echo "pipx is not installed. Install it with Homebrew first: brew install pipx" >&2
  exit 1
fi

if [[ ! -f "${PIPXFILE}" ]]; then
  echo "Pipxfile not found: ${PIPXFILE}" >&2
  exit 1
fi

package_count="$(read_pipx_packages | awk 'NF { count++ } END { print count + 0 }')"
ui_init "$((package_count + 1))" "pipx application installation"

while IFS= read -r package; do
  ui_stage "Checking pipx package: ${package}"
  install_pipx_package "${package}"
done < <(read_pipx_packages)

ui_stage "Ensuring the pipx binary directory is on PATH"
pipx ensurepath
ui_done "pipx PATH configuration is current"

ui_complete "pipx applications are satisfied"
