#!/usr/bin/env bash
set -euo pipefail

# Resolve this script's real directory even when invoked through a symlink,
# following the link chain manually rather than trusting $0 or BASH_SOURCE.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
ROOT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
MANIFEST="${ROOT_DIR}/features.yaml"

profile_name="daily"
profile_file=""
dry_run=false
bootstrap=true
list_requested=false
continue_on_error=true
declare -a only=() skipped=() forced_options=()
declare -a succeeded=() failed=()
declare -a cli_tiers=() picks=()
declare -a selected_tiers=()
TIERS_DIR="${ROOT_DIR}/tiers"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs a profile: a named set of tiers. profiles/air.yaml is a Mac that
is not a development machine, profiles/daily.yaml (the default) is a working
development machine, profiles/everything.yaml is every tier but optional.

A tier is both a package list (tiers/<NAME>.Brewfile) and a node selector:
every node in features.yaml whose `tier` is in the profile's list installs,
in registry order. Packages from all selected tiers are merged and installed
in one brew bundle before any node runs.

Each node may declare an `options` map in features.yaml (booleans forwarded
as `--<key>` to that node's own install.sh). A profile's own options for a
node override features.yaml's key-by-key. The flags below force a matching
option on for a single run on top of both, without editing either file.

Options:
  --profile NAME        Profile to install: profiles/NAME.yaml. A profile
                         names the tiers to install; every node whose tier is
                         in that list installs. Default: daily
  --file PATH           Install from a profile file at an explicit path.
                         Relative names are resolved from this checkout.
  --essential           Deprecated alias for --profile daily.
  --full                Deprecated alias for --profile everything.
  --tier NAME            Install this tier's packages; repeatable. Overrides the
                         tier set implied by the profile. Names come from
                         tiers/<NAME>.Brewfile.
  --pick TOKEN           Install one commented entry from tiers/optional.Brewfile
                         by name (e.g. --pick orbstack); repeatable.
  --only ID              Install only this node from the selection; may be
                         repeated.
  --skip ID              Skip a node from the selection; may be repeated.
  --list                 List the selection file's resolved plan and exit.
  --no-bootstrap         Do not install Homebrew/yq when missing.
  --macos-defaults       Force essentialDots' macos-defaults option on for this run.
  --pipx                 Force essentialDots' pipx option on for this run.
  --with-turbo-fieldfare Force localLLM's with-turbo-fieldfare option on for this run.
  --continue-on-error    Continue after a node fails (default).
  --stop-on-error        Stop at the first failing node instead.
  --dry-run              Show what would run without changing anything.
  -h, --help             Show this help.
EOF
}

is_in() {
  local wanted="$1" item; shift
  for item in "$@"; do [[ "${item}" == "${wanted}" ]] && return 0; done
  return 1
}

# --essential/--full predate profiles. bootstrap.sh and sync.sh still pass
# them, so they map onto the nearest profile rather than failing.
deprecated_alias() {
  echo "Note: $1 is deprecated; using --profile $2." >&2
  profile_name="$2"
}

resolve_file() {
  local requested="$1"
  if [[ "${requested}" = /* ]]; then printf '%s' "${requested}";
  else printf '%s' "${ROOT_DIR}/${requested}"; fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) shift; [[ $# -gt 0 ]] || { echo "--file requires a path" >&2; exit 2; }; profile_file="$(resolve_file "$1")" ;;
    --file=*) profile_file="$(resolve_file "${1#*=}")" ;;
    --profile) shift; [[ $# -gt 0 ]] || { echo "--profile requires a name" >&2; exit 2; }; profile_name="$1" ;;
    --profile=*) profile_name="${1#*=}" ;;
    --essential) deprecated_alias --essential daily ;;
    --full) deprecated_alias --full everything ;;
    --tier) shift; [[ $# -gt 0 ]] || { echo "--tier requires a name" >&2; exit 2; }; cli_tiers+=("$1") ;;
    --tier=*) cli_tiers+=("${1#*=}") ;;
    --pick) shift; [[ $# -gt 0 ]] || { echo "--pick requires a name" >&2; exit 2; }; picks+=("$1") ;;
    --pick=*) picks+=("${1#*=}") ;;
    --only) shift; [[ $# -gt 0 ]] || { echo "--only requires a node id" >&2; exit 2; }; only+=("$1") ;;
    --only=*) only+=("${1#*=}") ;;
    --skip) shift; [[ $# -gt 0 ]] || { echo "--skip requires a node id" >&2; exit 2; }; skipped+=("$1") ;;
    --skip=*) skipped+=("${1#*=}") ;;
    --no-bootstrap) bootstrap=false ;;
    --macos-defaults) forced_options+=(macos-defaults) ;;
    --pipx) forced_options+=(pipx) ;;
    --with-turbo-fieldfare) forced_options+=(with-turbo-fieldfare) ;;
    --continue-on-error) continue_on_error=true ;;
    --stop-on-error) continue_on_error=false ;;
    --dry-run) dry_run=true ;;
    --list) list_requested=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -f "${MANIFEST}" ]] || { echo "Missing manifest: ${MANIFEST}" >&2; exit 1; }
[[ -n "${profile_file}" ]] || profile_file="${ROOT_DIR}/profiles/${profile_name}.yaml"
[[ -f "${profile_file}" ]] || { echo "Missing profile: ${profile_file}" >&2; exit 1; }

# Looks up a node's `path` from the master registry (features.yaml) by id.
master_node_path() {
  yq -o=json ".nodes[] | select(.id == \"$1\") | .path" "${MANIFEST}" | jq -r '.'
}

# Looks up a node's `options` map from the master registry by id, as compact JSON.
master_node_options() {
  yq -o=json ".nodes[] | select(.id == \"$1\") | .options // {}" "${MANIFEST}" | jq -c '.'
}

# Reads the profile's tier list, one per line.
profile_tiers() {
  yq -o=json '.tiers // []' "${profile_file}" | jq -r '.[]'
}

# Every node whose tier is in the selected set, in registry order. This is
# the whole of node selection now -- there is no separate list to keep in
# sync with the tiers, which is what used to let a node and its own packages
# disagree (the vsCode cask installing without the vsCode extensions).
selected_node_ids() {
  local id tier
  while IFS=$'\t' read -r id tier; do
    [[ -n "${id}" ]] || continue
    is_in "${tier}" "${selected_tiers[@]}" && printf '%s\n' "${id}"
  done < <(yq -o=json '.nodes' "${MANIFEST}" | jq -r '.[] | [.id, (.tier // "")] | @tsv')
}

# Reads a node's options override from the profile, as compact JSON.
profile_node_options() {
  yq -o=json ".options.\"$1\" // {}" "${profile_file}" | jq -c '.'
}

# Prints a node's option keys whose effective value is true: features.yaml's
# default, overridden key-by-key by the profile's own options for
# that node, overridden again by a matching --<key> CLI flag (forced_options)
# -- one key per line.
node_true_options() {
  local id="$1" key value merged
  merged="$(jq -c -s '.[0] * .[1]' <(master_node_options "${id}") <(profile_node_options "${id}"))"
  while IFS=$'\t' read -r key value; do
    [[ -n "${key}" ]] || continue
    if [[ "${value}" == "true" ]]; then
      printf '%s\n' "${key}"
    elif [[ "${#forced_options[@]}" -gt 0 ]] && is_in "${key}" "${forced_options[@]}"; then
      printf '%s\n' "${key}"
    fi
  done < <(printf '%s' "${merged}" | jq -r 'to_entries[] | [.key, .value] | @tsv')
}

# Packages are declared per tier under tiers/, not per node, so Homebrew
# resolves each formula once per run instead of once per node that named it
# (stow alone appeared in 8 of the 13 old per-node Brewfiles). Nodes are still
# selected by the selection file; only their packages moved here.
resolve_tiers() {
  if [[ "${#cli_tiers[@]}" -gt 0 ]]; then
    selected_tiers=("${cli_tiers[@]}")
    return
  fi
  # Read loop rather than mapfile: on a fresh Mac this script runs before it
  # has bootstrapped Homebrew, so /usr/bin/env bash is still macOS's system
  # bash 3.2, which has no mapfile/readarray.
  local tier
  selected_tiers=()
  while IFS= read -r tier; do
    [[ -n "${tier}" ]] || continue
    selected_tiers+=("${tier}")
  done < <(profile_tiers)
  [[ "${#selected_tiers[@]}" -gt 0 ]] || {
    echo "Profile names no tiers: ${profile_file}" >&2
    return 1
  }
}

# Fanless Macs -- every Apple Silicon MacBook Air, and the 12-inch MacBook --
# have nothing for TG Pro to report on or control, so it is skipped there.
# Model Name is used rather than the model identifier because Apple's
# identifiers stopped encoding the family ("Mac14,2" is an M2 Air) while the
# marketing name did not. ioreg is not an option: fan data moved behind
# IOHIDEventSystemClient on Apple Silicon and is invisible to `ioreg -c AppleSMC`.
machine_has_fans() {
  local model
  model="$(system_profiler SPHardwareDataType 2>/dev/null |
    awk -F': ' '/Model Name/ { print $2; exit }')"
  case "${model}" in
    "MacBook Air" | "MacBook") return 1 ;;
    *) return 0 ;;
  esac
}

# Uncomments one named entry from tiers/optional.Brewfile into the merged file
# for this run only. optional/ is never pulled by a profile, so this is the
# sole path by which docker-desktop, orbstack, raycast, uv, and the work-comms
# casks get installed.
append_picks() {
  local merged="$1" pick line
  for pick in "${picks[@]}"; do
    line="$(sed -nE "s/^[[:space:]]*#[[:space:]]*((brew|cask) \"${pick}\".*)$/\1/p" \
      "${TIERS_DIR}/optional.Brewfile" | head -1)"
    if [[ -z "${line}" ]]; then
      echo "No entry named '${pick}' in ${TIERS_DIR}/optional.Brewfile" >&2
      return 1
    fi
    printf '%s\n' "${line}" >>"${merged}"
  done
}

merge_tier_brewfiles() {
  local merged="$1" tier file
  : >"${merged}"
  for tier in "${selected_tiers[@]}"; do
    file="${TIERS_DIR}/${tier}.Brewfile"
    [[ -f "${file}" ]] || { echo "Unknown tier: ${tier} (no ${file})" >&2; return 1; }
    cat "${file}" >>"${merged}"
  done

  # TG Pro is the one package chosen by hardware rather than by tier: it is
  # only meaningful where there are fans to report on. macos-defaults.sh
  # applies the matching guard to its preference keys.
  if is_in mac-essentials "${selected_tiers[@]}" && machine_has_fans; then
    printf 'cask "tg-pro" # Auto-selected: this Mac has fans.\n' >>"${merged}"
  fi

  [[ "${#picks[@]}" -eq 0 ]] || append_picks "${merged}" || return 1

  # brew bundle tolerates duplicate lines, but deduping keeps --list readable
  # and makes the "one declaration per package" property easy to verify.
  sort -u -o "${merged}" "${merged}"
}

if [[ "${list_requested}" == true ]]; then
  command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }
  resolve_tiers
  echo "Profile:        ${profile_file}"
  echo "Tiers:          ${selected_tiers[*]}"
  [[ "${#picks[@]}" -eq 0 ]] || echo "Picks:          ${picks[*]}"
  if machine_has_fans; then
    echo "Fans:           yes (tg-pro will be included with mac-essentials)"
  else
    echo "Fans:           no (tg-pro skipped)"
  fi
  echo
  printf '%-38s %-40s %s\n' ID PATH OPTIONS
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    path="$(master_node_path "${id}")"
    opts="$(node_true_options "${id}" | paste -sd, - 2>/dev/null)"
    printf '%-38s %-40s %s\n' "${id}" "${path}" "${opts:--}"
  done < <(selected_node_ids)
  exit 0
fi

if ! xcode-select -p >/dev/null 2>&1; then
  if [[ "${dry_run}" == true ]]; then
    echo "Would start Apple's command-line tools installer"
    exit 0
  fi
  # This always exits 1: Apple's installer runs asynchronously and the
  # caller must rerun this script once it finishes.
  echo "Apple's command-line tools are required. Complete the installer, then rerun this command."
  xcode-select --install
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "Git is required. Install Apple's command-line tools first." >&2; exit 1; }

# A fresh Homebrew install only updates the current shell's env via
# shellenv; later steps (and a plain `command -v brew`) need it re-sourced.
load_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)";
  elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)";
  fi
}
load_homebrew
if ! command -v brew >/dev/null 2>&1; then
  if [[ "${dry_run}" == true ]]; then
    echo "Would install Homebrew before installing components"
  elif [[ "${bootstrap}" == true ]]; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_homebrew
    command -v brew >/dev/null 2>&1 || { echo "Homebrew was installed but is not available on PATH; open a new shell and retry." >&2; exit 1; }
  else
    echo "Homebrew is required; install it or omit --no-bootstrap." >&2
    exit 1
  fi
fi

if ! command -v yq >/dev/null 2>&1; then
  if [[ "${dry_run}" == true ]]; then
    echo "Would install yq (used to read features.yaml) before installing components"
  elif [[ "${bootstrap}" == true ]]; then
    echo "Installing yq..."
    brew install yq
  else
    echo "yq is required to read features.yaml; install it or omit --no-bootstrap." >&2
    exit 1
  fi
fi
command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }

run_node() {
  local id="$1" path installer
  path="$(master_node_path "${id}")"
  [[ -n "${path}" && "${path}" != "null" ]] || { echo "Unknown node id (not in features.yaml): ${id}" >&2; return 1; }
  local checkout="${ROOT_DIR}/${path}"
  installer="${checkout}/install.sh"
  # Packages come from the merged tier Brewfile installed once before this
  # loop, so every node runs with brew disabled and does config work only.
  # Profile flags are no longer forwarded: a node's tier already decided
  # whether it runs, and nodes have nothing left to vary by profile.
  local -a install_args=(--no-brew)

  # essentialDots is the one node whose config spans tiers -- shell and Git
  # for every machine, AeroSpace/borders for the desktop, Python only for a
  # development machine -- so it needs the tier list to know what to stow.
  # Every other node owns a single tier's worth of config by construction.
  if [[ "${id}" == "essentialDots" ]]; then
    local tier
    for tier in "${selected_tiers[@]}"; do
      install_args+=(--tier "${tier}")
    done
  fi

  local option
  while IFS= read -r option; do
    [[ -n "${option}" ]] || continue
    install_args+=("--${option}")
  done < <(node_true_options "${id}")

  echo
  echo "==> ${id}"
  [[ -x "${installer}" ]] || { echo "Missing executable installer: ${installer}" >&2; return 1; }
  if [[ "${dry_run}" == true ]]; then
    "${installer}" "${install_args[@]}" --dry-run
  else
    "${installer}" "${install_args[@]}"
  fi
}

# mac-essentials declares both third-party taps, and Homebrew refuses to load
# formulae from an untrusted tap. This ran inside essentialDots' brew stage
# before packages were centralized; it has to happen here now, ahead of the
# single bundle run.
trust_required_homebrew_taps() {
  mkdir -p "${XDG_CONFIG_HOME:-${HOME}/.config}/homebrew"
  brew trust --tap felixkratz/formulae
  brew trust --tap nikitabobko/tap
}

resolve_tiers
MERGED_BREWFILE="$(mktemp -t intellidots-brewfile)"
trap 'rm -f "${MERGED_BREWFILE}"' EXIT
merge_tier_brewfiles "${MERGED_BREWFILE}"

echo
echo "==> packages (tiers: ${selected_tiers[*]})"
if [[ "${dry_run}" == true ]]; then
  echo "Would install $(grep -cE '^[[:space:]]*(brew|cask) ' "${MERGED_BREWFILE}") packages from the merged tier Brewfile:"
  sed -nE 's/^[[:space:]]*(brew|cask) "([^"]+)".*/  \1 \2/p' "${MERGED_BREWFILE}"
else
  trust_required_homebrew_taps
  "${ROOT_DIR}/essentialDots/scripts/install-brew-bundle.sh" "${MERGED_BREWFILE}"
fi

matched=false
while IFS= read -r id; do
  [[ -n "${id}" ]] || continue

  if [[ "${#only[@]}" -gt 0 ]] && ! is_in "${id}" "${only[@]}"; then continue; fi
  matched=true

  if [[ "${#skipped[@]}" -gt 0 ]] && is_in "${id}" "${skipped[@]}"; then
    echo "Skipping ${id}"
    continue
  fi

  if run_node "${id}"; then
    succeeded+=("${id}")
  else
    failed+=("${id}")
    [[ "${continue_on_error}" == true ]] || break
  fi
done < <(selected_node_ids)

if [[ "${#only[@]}" -gt 0 && "${matched}" == false ]]; then
  echo "No node in tiers [${selected_tiers[*]}] matched: ${only[*]}" >&2
  exit 2
fi

echo
echo "Installation summary"
echo "  succeeded: ${succeeded[*]:-none}"
echo "  failed:    ${failed[*]:-none}"
[[ -z "${failed[*]-}" ]]
