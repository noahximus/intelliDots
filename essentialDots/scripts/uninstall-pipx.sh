#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIPXFILE="${DOTFILES_DIR}/Pipxfile"
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./scripts/uninstall-pipx.sh [--pipxfile FILE|NAME] [--dry-run]

Options:
  --pipxfile FILE|NAME Uninstall packages from a specific Pipxfile.
                        Relative names are resolved from this dotfiles directory.
  --dry-run            Print what would be uninstalled.
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

uninstall_pipx_package() {
  local package="$1"

  if ! pipx_package_installed "${package}"; then
    echo "Not installed: ${package}"
    return
  fi

  if [[ "${dry_run}" == true ]]; then
    echo "DRY RUN: pipx uninstall ${package}"
    return
  fi

  echo "Uninstalling ${package}..."
  pipx uninstall "${package}"
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
    --dry-run)
      dry_run=true
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
  echo "pipx is not installed; skipping pipx CLI uninstall." >&2
  exit 0
fi

if [[ ! -f "${PIPXFILE}" ]]; then
  echo "Pipxfile not found: ${PIPXFILE}" >&2
  exit 1
fi

while IFS= read -r package; do
  uninstall_pipx_package "${package}"
done < <(read_pipx_packages)

echo "pipx CLI uninstall complete."
