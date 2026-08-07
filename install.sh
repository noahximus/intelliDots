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

profile=essential
dry_run=false
bootstrap=true
all_nodes=false
apply_macos_defaults=false
with_turbo_fieldfare=false
pipx=false
continue_on_error=true
declare -a only=() skipped=()
declare -a succeeded=() failed=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs the components selected in features.yaml. Nodes marked `default:
true` (essentialDots, myITerm, myNvim) install unless narrowed with --only;
--all additionally installs every optional node (myVSCode, myLocalLLM,
myOpenCode).

Options:
  --essential           Install each component's essential profile (default).
  --full                Install each component's full profile.
  --all                 Install every node in features.yaml, not just the
                         defaults.
  --only ID             Install only this node; may be repeated. Overrides
                         --all and the default selection.
  --skip ID             Skip a node; may be repeated.
  --list                List configured nodes (id, path, default) and exit.
  --no-bootstrap        Do not install Homebrew/yq when missing.
  --macos-defaults      Apply tracked macOS preferences through essentialDots.
  --pipx                Install essentialDots' Pipxfile applications with pipx.
  --with-turbo-fieldfare Also install myLocalLLM's TurboFieldfare backend.
  --continue-on-error   Continue after a node fails (default).
  --stop-on-error       Stop at the first failing node instead.
  --dry-run             Show what would run without changing anything.
  -h, --help            Show this help.
EOF
}

is_in() {
  local wanted="$1" item; shift
  for item in "$@"; do [[ "${item}" == "${wanted}" ]] && return 0; done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --essential) profile=essential ;;
    --full) profile=full ;;
    --all) all_nodes=true ;;
    --only) shift; [[ $# -gt 0 ]] || { echo "--only requires a node id" >&2; exit 2; }; only+=("$1") ;;
    --only=*) only+=("${1#*=}") ;;
    --skip) shift; [[ $# -gt 0 ]] || { echo "--skip requires a node id" >&2; exit 2; }; skipped+=("$1") ;;
    --skip=*) skipped+=("${1#*=}") ;;
    --no-bootstrap) bootstrap=false ;;
    --macos-defaults) apply_macos_defaults=true ;;
    --pipx) pipx=true ;;
    --with-turbo-fieldfare) with_turbo_fieldfare=true ;;
    --continue-on-error) continue_on_error=true ;;
    --stop-on-error) continue_on_error=false ;;
    --dry-run) dry_run=true ;;
    --list)
      command -v yq >/dev/null 2>&1 || { echo "yq is required (brew install yq)." >&2; exit 1; }
      yq -o=json '.nodes' "${MANIFEST}" | jq -r '.[] | "\(.id)\t\(.path)\tdefault=\(.default)"'
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -f "${MANIFEST}" ]] || { echo "Missing manifest: ${MANIFEST}" >&2; exit 1; }

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

# Reads features.yaml into "id<TAB>path<TAB>default" lines, in file order.
manifest_nodes() {
  yq -o=json '.nodes' "${MANIFEST}" | jq -r '.[] | [.id, .path, (.default // false)] | @tsv'
}

run_node() {
  local id="$1" path="$2" checkout="${ROOT_DIR}/${path}" installer
  local -a install_args=(--"${profile}")
  installer="${checkout}/install.sh"

  if [[ "${id}" == "essentialDots" ]]; then
    [[ "${apply_macos_defaults}" == true ]] && install_args+=(--macos-defaults)
    [[ "${pipx}" == true ]] && install_args+=(--pipx)
  fi
  # myLocalLLM has no packages of its own without an explicit backend flag;
  # local-llm (llama.cpp) is on by default, with TurboFieldfare staying
  # strictly opt-in given its size and hardware requirements.
  if [[ "${id}" == "toolsDots.aiTools.myLocalLLM" ]]; then
    install_args+=(--with-local-llm)
    [[ "${with_turbo_fieldfare}" == true ]] && install_args+=(--with-turbo-fieldfare)
  fi

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
while IFS=$'\t' read -r id path default; do
  [[ -n "${id}" ]] || continue

  if [[ "${#only[@]}" -gt 0 ]]; then
    is_in "${id}" "${only[@]}" || continue
  elif [[ "${all_nodes}" == false && "${default}" != "true" ]]; then
    continue
  fi
  matched=true

  if [[ "${#skipped[@]}" -gt 0 ]] && is_in "${id}" "${skipped[@]}"; then
    echo "Skipping ${id}"
    continue
  fi

  if run_node "${id}" "${path}"; then
    succeeded+=("${id}")
  else
    failed+=("${id}")
    [[ "${continue_on_error}" == true ]] || break
  fi
done < <(manifest_nodes)

if [[ "${#only[@]}" -gt 0 && "${matched}" == false ]]; then
  echo "No node in features.yaml matched: ${only[*]}" >&2
  exit 2
fi

echo
echo "Installation summary"
echo "  succeeded: ${succeeded[*]:-none}"
echo "  failed:    ${failed[*]:-none}"
[[ -z "${failed[*]-}" ]]
