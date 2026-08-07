#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$(cd "${PROJECT_DIR}/../../.." && pwd)/features.yaml"
NODE_ID="toolsDots.devTools.vsCode"
BREWFILE="${PROJECT_DIR}/Brewfile-essential"
EXTENSIONSFILE=""
run_brew=true
run_extensions=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--no-extensions] [--extensionsfile FILE|NAME] [--dry-run]

Installs VS Code and the tracked extension set. The essential Brewfile is the
default; --full is accepted for a consistent component interface and
currently installs the same package set.

By default, extensions come from this node's `extensions` list in
features.yaml (../../../features.yaml) -- comment out or delete a line
there to skip installing that one extension. --extensionsfile overrides
that with a flat file instead:

  publisher.extension-id
  publisher.extension-id # optional comment

Blank lines and comments are ignored in that file format.
EOF
}

resolve_extensionsfile() {
  local requested="$1"
  if [[ "${requested}" = /* ]]; then
    EXTENSIONSFILE="${requested}"
  else
    EXTENSIONSFILE="${PROJECT_DIR}/${requested}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    # No distinct full Brewfile yet; both branches point at the same file so
    # the root installer can pass --full uniformly across every component.
    --essential) BREWFILE="${PROJECT_DIR}/Brewfile-essential" ;;
    --full) BREWFILE="${PROJECT_DIR}/Brewfile-essential" ;;
    --no-brew) run_brew=false ;;
    --no-extensions) run_extensions=false ;;
    --extensionsfile)
      shift
      [[ $# -gt 0 ]] || { echo "--extensionsfile requires a file path or name" >&2; exit 2; }
      resolve_extensionsfile "$1"
      ;;
    --extensionsfile=*) resolve_extensionsfile "${1#*=}" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

# Reads the tracked extension list: from --extensionsfile if given (a flat
# "publisher.id # comment" file), otherwise from this node's `extensions`
# array in features.yaml -- commenting out a line there is enough to skip it.
read_extensions() {
  if [[ -n "${EXTENSIONSFILE}" ]]; then
    [[ -f "${EXTENSIONSFILE}" ]] || { echo "Extensions file not found: ${EXTENSIONSFILE}" >&2; exit 1; }
    local raw line
    while IFS= read -r raw || [[ -n "${raw}" ]]; do
      line="${raw%%#*}"
      line="$(trim "${line}")"
      [[ -n "${line}" ]] || continue
      printf '%s\n' "${line}"
    done < "${EXTENSIONSFILE}"
  else
    command -v yq >/dev/null 2>&1 || { echo "yq is required to read extensions from features.yaml (brew install yq), or pass --extensionsfile." >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }
    [[ -f "${MANIFEST}" ]] || { echo "Missing manifest: ${MANIFEST}" >&2; exit 1; }
    yq -o=json ".nodes[] | select(.id == \"${NODE_ID}\") | .extensions // []" "${MANIFEST}" | jq -r '.[]'
  fi
}

extension_installed() {
  code --list-extensions 2>/dev/null | grep -Fixq "$1"
}

if [[ "${dry_run}" == true ]]; then
  [[ "${run_brew}" == true ]] && echo "Would install ${BREWFILE}"
  if [[ "${run_extensions}" == true ]]; then
    while IFS= read -r extension; do
      echo "Would ensure VS Code extension installed: ${extension}"
    done < <(read_extensions)
  fi
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew is required." >&2; exit 1; }
  brew bundle --file="${BREWFILE}" --no-upgrade
fi

if [[ "${run_extensions}" == true ]]; then
  command -v code >/dev/null 2>&1 || {
    echo "The 'code' command is not on PATH. Install VS Code first, then run 'Shell Command: Install code command in PATH' from VS Code's command palette." >&2
    exit 1
  }
  while IFS= read -r extension; do
    if extension_installed "${extension}"; then
      echo "Already installed: ${extension}"
    else
      echo "Installing missing extension: ${extension}"
      code --install-extension "${extension}"
    fi
  done < <(read_extensions)
fi

echo "vsCode installed."
