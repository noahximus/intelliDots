#!/usr/bin/env bash
set -euo pipefail

# One-time bridge tool: uninstalls (unlinks) a pre-intelliDots checkout of
# myDotFiles/myITerm/myNvim/myLocalLLM/myOpenCode -- the six-repo setup this
# project replaces -- so intelliDots can be installed fresh without GNU Stow
# refusing to touch symlinks it doesn't recognize as its own.
#
# Self-contained: this file has no dependency on the rest of the intelliDots
# checkout, so it can be downloaded and run by itself on a machine that has
# the old repos but not yet intelliDots.
#
# Safe by default: only unlinks each component's managed symlinks. It does
# NOT uninstall Homebrew packages or remove generated data/models unless you
# explicitly pass --remove-brew / --remove-data. Git checkouts are left on
# disk; delete them yourself once intelliDots is confirmed working.
#
# Components are uninstalled in the reverse of intelliDots' install order.
# Any component not found at LEGACY_ROOT is skipped, not an error, since a
# given machine may only have some of the six installed.

LEGACY_ROOT="${MY_CONFIG_ROOT:-${HOME}/Developer/myConfigs}"
dry_run=false
remove_brew=false
remove_data=false
declare -a only=()

# name|uninstaller relative path (myDotFiles' lives under scripts/, not at
# its checkout root -- that repo never had a top-level uninstall.sh)
LEGACY_COMPONENTS=(
  "myOpenCode|uninstall.sh"
  "myLocalLLM|uninstall.sh"
  "myNvim|uninstall.sh"
  "myITerm|uninstall.sh"
  "myDotFiles|scripts/uninstall.sh"
)

usage() {
  cat <<'EOF'
Usage: ./uninstall-legacy.sh [options]

Unlinks a pre-intelliDots myDotFiles/myITerm/myNvim/myLocalLLM/myOpenCode
setup so intelliDots can be installed fresh. Safe by default: only removes
each component's managed symlinks.

Options:
  --root DIRECTORY   Parent directory containing the old checkouts.
                      Default: ${MY_CONFIG_ROOT:-~/Developer/myConfigs}
  --only NAME         Uninstall only this legacy component; may be repeated.
                      Names: myOpenCode, myLocalLLM, myNvim, myITerm, myDotFiles
  --remove-brew       Also uninstall each component's Homebrew formulae/casks.
  --remove-data       Also remove generated data/cache directories.
  --dry-run           Show what would be removed without changing anything.
  -h, --help          Show this help.

Git checkouts under --root are never deleted by this script. Once intelliDots
is confirmed working, remove them yourself, e.g.:
  rm -rf "${MY_CONFIG_ROOT:-~/Developer/myConfigs}"/{myDotFiles,myITerm,myNvim,myLocalLLM,myOpenCode,myAILab,myConfigMaster}
EOF
}

is_in() {
  local wanted="$1" item; shift
  for item in "$@"; do [[ "${item}" == "${wanted}" ]] && return 0; done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) shift; [[ $# -gt 0 ]] || { echo "--root requires a directory" >&2; exit 2; }; LEGACY_ROOT="$1" ;;
    --root=*) LEGACY_ROOT="${1#*=}" ;;
    --only) shift; [[ $# -gt 0 ]] || { echo "--only requires a component name" >&2; exit 2; }; only+=("$1") ;;
    --only=*) only+=("${1#*=}") ;;
    --remove-brew) remove_brew=true ;;
    --remove-data) remove_data=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -d "${LEGACY_ROOT}" ]] || { echo "Not a directory: ${LEGACY_ROOT}" >&2; exit 1; }

declare -a processed=() skipped_missing=() failed=()

for entry in "${LEGACY_COMPONENTS[@]}"; do
  name="${entry%%|*}"
  rel="${entry#*|}"

  if [[ "${#only[@]}" -gt 0 ]] && ! is_in "${name}" "${only[@]}"; then
    continue
  fi

  checkout="${LEGACY_ROOT}/${name}"
  uninstaller="${checkout}/${rel}"

  if [[ ! -x "${uninstaller}" ]]; then
    echo "Skipping ${name}: not found at ${uninstaller}"
    skipped_missing+=("${name}")
    continue
  fi

  declare -a args=()
  [[ "${dry_run}" == true ]] && args+=(--dry-run)
  if [[ "${name}" == "myDotFiles" ]]; then
    # myDotFiles' uninstaller prompts interactively and defaults to removing
    # brew packages and data; --yes plus the keep-* flags make this call
    # match every other component's unlink-only default.
    args+=(--yes)
    [[ "${remove_brew}" == false ]] && args+=(--keep-brew)
    [[ "${remove_data}" == false ]] && args+=(--keep-data)
  else
    [[ "${name}" == "myITerm" && "${remove_brew}" == true ]] && args+=(--brew)
    [[ "${name}" == "myNvim" && "${remove_data}" == true ]] && args+=(--data)
    [[ "${name}" == "myLocalLLM" && "${remove_data}" == true ]] && args+=(--data)
  fi

  echo
  echo "==> Uninstalling legacy ${name}"
  if "${uninstaller}" "${args[@]}"; then
    processed+=("${name}")
  else
    echo "Failed to uninstall ${name}; continuing with the rest." >&2
    failed+=("${name}")
  fi
done

echo
echo "Legacy uninstall summary"
echo "  unlinked: ${processed[*]:-none}"
echo "  not found: ${skipped_missing[*]:-none}"
echo "  failed:    ${failed[*]:-none}"
echo
echo "Git checkouts under ${LEGACY_ROOT} were left in place. Once intelliDots"
echo "is confirmed working, remove them yourself, e.g.:"
echo "  rm -rf ${LEGACY_ROOT}/{myDotFiles,myITerm,myNvim,myLocalLLM,myOpenCode,myAILab,myConfigMaster}"

[[ -z "${failed[*]:-}" ]]
