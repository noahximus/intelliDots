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

[[ $# -eq 0 ]] || { echo "Usage: ./status.sh" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }

printf '%-38s %-9s %s\n' NODE PRESENT NVIM-INTEGRATION
while IFS=$'\t' read -r id path integration_path; do
  [[ -n "${id}" ]] || continue
  checkout="${ROOT_DIR}/${path}"
  present="no"
  [[ -x "${checkout}/install.sh" ]] && present="yes"

  integration="-"
  if [[ -n "${integration_path}" && "${integration_path}" != "null" ]]; then
    expanded="${integration_path/#\~/${HOME}}"
    if [[ -f "${expanded}" ]]; then integration="active"; else integration="inactive"; fi
  fi

  printf '%-38s %-9s %s\n' "${id}" "${present}" "${integration}"
done < <(yq -o=json '.nodes' "${MANIFEST}" | jq -r '.[] | [.id, .path, (.nvim_integration_path // "")] | @tsv')
