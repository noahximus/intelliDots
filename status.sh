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
# shellcheck source=essentialDots/scripts/lib/hardware.sh
. "${ROOT_DIR}/essentialDots/scripts/lib/hardware.sh"

profile_name="daily"

usage() {
  cat <<'EOF'
Usage: ./status.sh [--profile NAME]

Reports each node's tier, whether the named profile selects it, whether its
checkout is present, and the state of its Neovim integration. Also reports
the hardware-dependent TG Pro decision.

Options:
  --profile NAME  Profile to resolve against. Default: daily
  -h, --help      Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      [[ $# -gt 0 ]] || { echo "--profile requires a name" >&2; exit 2; }
      profile_name="$1"
      ;;
    --profile=*) profile_name="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }

PROFILE_FILE="${ROOT_DIR}/profiles/${profile_name}.yaml"
[[ -f "${PROFILE_FILE}" ]] || { echo "Missing profile: ${PROFILE_FILE}" >&2; exit 1; }

is_in() {
  local wanted="$1" item; shift
  for item in "$@"; do [[ "${item}" == "${wanted}" ]] && return 0; done
  return 1
}

# Read loop rather than mapfile, matching install.sh: this has to keep working
# under macOS's system bash 3.2.
declare -a selected_tiers=()
while IFS= read -r tier; do
  [[ -n "${tier}" ]] || continue
  selected_tiers+=("${tier}")
done < <(yq -o=json '.tiers // []' "${PROFILE_FILE}" | jq -r '.[]')

echo "Profile: ${profile_name}"
echo "Tiers:   ${selected_tiers[*]}"
echo

printf '%-38s %-16s %-9s %-9s %s\n' NODE TIER SELECTED PRESENT NVIM-INTEGRATION
while IFS=$'\t' read -r id tier path integration_path; do
  [[ -n "${id}" ]] || continue
  checkout="${ROOT_DIR}/${path}"
  present="no"
  [[ -x "${checkout}/install.sh" ]] && present="yes"

  selected="no"
  is_in "${tier}" "${selected_tiers[@]}" && selected="yes"

  integration="-"
  if [[ -n "${integration_path}" && "${integration_path}" != "null" ]]; then
    expanded="${integration_path/#\~/${HOME}}"
    if [[ -f "${expanded}" ]]; then integration="active"; else integration="inactive"; fi
  fi

  printf '%-38s %-16s %-9s %-9s %s\n' "${id}" "${tier:--}" "${selected}" "${present}" "${integration}"
done < <(yq -o=json '.nodes' "${MANIFEST}" |
  jq -r '.[] | [.id, (.tier // ""), .path, (.nvim_integration_path // "")] | @tsv')

# TG Pro is the one package chosen by hardware rather than by tier, so its
# state is not visible anywhere in the table above.
echo
if machine_has_fans; then
  echo "TG Pro:  this Mac has fans, so mac-essentials includes it"
  if [[ -d "/Applications/TG Pro.app" ]]; then
    if defaults read com.tunabellysoftware.tgpro >/dev/null 2>&1; then
      echo "         installed, preferences applied"
    else
      echo "         installed, preferences not yet applied (run macos-defaults.sh)"
    fi
  else
    echo "         not installed"
  fi
else
  echo "TG Pro:  this Mac has no fans, so it is skipped (--pick tg-pro overrides)"
fi
