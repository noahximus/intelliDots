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

cli_profile=""
selection_file="${ROOT_DIR}/features-default.yaml"
dry_run=false
bootstrap=true
list_requested=false
continue_on_error=true
declare -a only=() skipped=() forced_options=()
declare -a succeeded=() failed=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs the nodes listed in a selection file -- features-default.yaml
(the default), features-essential.yaml (every node, essential profile,
replaces the old install-essential.sh), features-all.yaml (every node,
full profile, replaces the old install-everything.sh), or a file of your
own. A selection file just lists node ids (+ optional profile and per-node
option overrides); each id's path and default options come from
features.yaml, the master registry.

Each node may declare an `options` map in features.yaml (booleans forwarded
as `--<key>` to that node's own install.sh). A selection file's own options
for a node override features.yaml's key-by-key. The flags below force a
matching option on for a single run on top of both, without editing either
file.

Options:
  --file PATH           Selection file to install from. Relative names are
                         resolved from this checkout. Default: features-default.yaml
  --essential           Force the essential profile for every node this run.
  --full                Force the full profile for every node this run.
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

resolve_file() {
  local requested="$1"
  if [[ "${requested}" = /* ]]; then printf '%s' "${requested}";
  else printf '%s' "${ROOT_DIR}/${requested}"; fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) shift; [[ $# -gt 0 ]] || { echo "--file requires a path" >&2; exit 2; }; selection_file="$(resolve_file "$1")" ;;
    --file=*) selection_file="$(resolve_file "${1#*=}")" ;;
    --essential) cli_profile=essential ;;
    --full) cli_profile=full ;;
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
[[ -f "${selection_file}" ]] || { echo "Missing selection file: ${selection_file}" >&2; exit 1; }

# Looks up a node's `path` from the master registry (features.yaml) by id.
master_node_path() {
  yq -o=json ".nodes[] | select(.id == \"$1\") | .path" "${MANIFEST}" | jq -r '.'
}

# Looks up a node's `options` map from the master registry by id, as compact JSON.
master_node_options() {
  yq -o=json ".nodes[] | select(.id == \"$1\") | .options // {}" "${MANIFEST}" | jq -c '.'
}

# Reads the selection file's top-level profile, if any (empty otherwise).
selection_profile() {
  yq -o=json '.profile // ""' "${selection_file}" | jq -r '.'
}

# Reads node ids from the selection file, in file order.
selection_node_ids() {
  yq -o=json '.nodes' "${selection_file}" | jq -r '.[].id'
}

# Reads a node's inline options override from the selection file, as compact JSON.
selection_node_options() {
  yq -o=json ".nodes[] | select(.id == \"$1\") | .options // {}" "${selection_file}" | jq -c '.'
}

# Prints a node's option keys whose effective value is true: features.yaml's
# default, overridden key-by-key by the selection file's own options for
# that node, overridden again by a matching --<key> CLI flag (forced_options)
# -- one key per line.
node_true_options() {
  local id="$1" key value merged
  merged="$(jq -c -s '.[0] * .[1]' <(master_node_options "${id}") <(selection_node_options "${id}"))"
  while IFS=$'\t' read -r key value; do
    [[ -n "${key}" ]] || continue
    if [[ "${value}" == "true" ]]; then
      printf '%s\n' "${key}"
    elif [[ "${#forced_options[@]}" -gt 0 ]] && is_in "${key}" "${forced_options[@]}"; then
      printf '%s\n' "${key}"
    fi
  done < <(printf '%s' "${merged}" | jq -r 'to_entries[] | [.key, .value] | @tsv')
}

if [[ "${list_requested}" == true ]]; then
  command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }
  resolved_profile="${cli_profile:-$(selection_profile)}"
  resolved_profile="${resolved_profile:-essential}"
  echo "Selection file: ${selection_file}"
  echo "Profile:        ${resolved_profile}"
  echo
  printf '%-38s %-40s %s\n' ID PATH OPTIONS
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    path="$(master_node_path "${id}")"
    opts="$(node_true_options "${id}" | paste -sd, - 2>/dev/null)"
    printf '%-38s %-40s %s\n' "${id}" "${path}" "${opts:--}"
  done < <(selection_node_ids)
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

resolved_profile="${cli_profile:-$(selection_profile)}"
resolved_profile="${resolved_profile:-essential}"

run_node() {
  local id="$1" path installer
  path="$(master_node_path "${id}")"
  [[ -n "${path}" && "${path}" != "null" ]] || { echo "Unknown node id (not in features.yaml): ${id}" >&2; return 1; }
  local checkout="${ROOT_DIR}/${path}"
  installer="${checkout}/install.sh"
  local -a install_args=(--"${resolved_profile}")

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
done < <(selection_node_ids)

if [[ "${#only[@]}" -gt 0 && "${matched}" == false ]]; then
  echo "No node in ${selection_file} matched: ${only[*]}" >&2
  exit 2
fi

echo
echo "Installation summary"
echo "  succeeded: ${succeeded[*]:-none}"
echo "  failed:    ${failed[*]:-none}"
[[ -z "${failed[*]-}" ]]
