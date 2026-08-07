#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
ROOT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
MANIFEST="${ROOT_DIR}/features.yaml"

dry_run=false
declare -a only=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) shift; [[ $# -gt 0 ]] || { echo "--only requires a node id" >&2; exit 2; }; only+=("$1") ;;
    --only=*) only+=("${1#*=}") ;;
    --dry-run) dry_run=true ;;
    -h|--help) echo "Usage: ./uninstall.sh [--only ID] [--dry-run]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }
[[ -f "${MANIFEST}" ]] || { echo "Missing manifest: ${MANIFEST}" >&2; exit 1; }

is_in() {
  local wanted="$1" item; shift
  for item in "$@"; do [[ "${item}" == "${wanted}" ]] && return 0; done
  return 1
}

# Read nodes into an array (uninstalled in reverse, bottom-to-top) since a
# process substitution's while-loop runs in a subshell and can't populate
# variables the caller sees afterward.
declare -a ids=() paths=()
while IFS=$'\t' read -r id path; do
  [[ -n "${id}" ]] || continue
  ids+=("${id}")
  paths+=("${path}")
done < <(yq -o=json '.nodes' "${MANIFEST}" | jq -r '.[] | [.id, .path] | @tsv')

for ((index=${#ids[@]}-1; index>=0; index--)); do
  id="${ids[index]}"
  path="${paths[index]}"
  if [[ "${#only[@]}" -gt 0 ]] && ! is_in "${id}" "${only[@]}"; then continue; fi

  checkout="${ROOT_DIR}/${path}"
  uninstaller="${checkout}/uninstall.sh"
  if [[ ! -x "${uninstaller}" ]]; then
    echo "Skipping ${id}; no executable uninstaller at ${uninstaller}"
    continue
  fi
  echo "==> Uninstalling ${id}"
  if [[ "${dry_run}" == true ]]; then "${uninstaller}" --dry-run; else "${uninstaller}"; fi
done

echo "Component configuration removed."
