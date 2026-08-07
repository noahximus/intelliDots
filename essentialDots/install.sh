#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${DOTFILES_DIR}/scripts"
# shellcheck source=scripts/lib/progress.sh
. "${SCRIPTS_DIR}/lib/progress.sh"
# Reports which numbered stage failed rather than a bare non-zero exit,
# since this installer runs many stages and the stage number alone
# localizes the failure without needing -x tracing.
trap 'ui_fail "Dotfiles installation stopped during stage ${UI_STEP:-0} of ${UI_TOTAL:-0}"' ERR
BREWFILE="${DOTFILES_DIR}/Brewfile-essential"
DEFAULT_NODE_VERSION="${DEFAULT_NODE_VERSION:-22.7.0}"
PYENV_PYTHON_VERSIONS="${PYENV_PYTHON_VERSIONS:-3.10.19 3.11.14 3.12.12}"
PYENV_GLOBAL_VERSIONS="${PYENV_GLOBAL_VERSIONS:-3.12.12 3.11.14 3.10.19 system}"
STOW_TARGET="${HOME}"
STOW_PACKAGES=(zsh local git python aerospace borders btop)
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${DOTFILES_DIR}" --target="${STOW_TARGET}" --verbose --restow --no-folding)
STOW_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/essentialDots"
# Records which checkout path stow last linked from, so a clone that later
# moves (or is replaced by a fresh clone elsewhere) can still recognize its
# own previously created links as stale instead of leaving them dangling.
STOW_ROOT_FILE="${STOW_STATE_DIR}/stow-root"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--adopt] [--dry-run] [--stow-only] [--no-brew] [--essential] [--full] [--brewfile FILE|NAME] [--pipx] [--pipxfile FILE|NAME] [--macos-defaults]

Options:
  --adopt              Let stow adopt existing files into this repo before linking.
                       Use this only when you intentionally want to absorb local files.
  --dry-run            Show stale symlinks that would be migrated and simulate Stow.
                       No packages, runtimes, or configuration are changed.
  --stow-only          Migrate and restow dotfile links without installing anything else.
  --no-brew            Skip brew bundle.
  --essential          Install Brewfile-essential (the default).
  --full               Install the expanded Brewfile instead of the essential set.
  --brewfile FILE|NAME Install a specific Brewfile. Relative names are resolved
                       from this dotfiles directory.
  --pipx               Install Python CLI apps listed in Pipxfile with pipx.
  --pipxfile FILE|NAME Install Python CLI apps from a specific Pipxfile.
                       Relative names are resolved from this dotfiles directory.
  --macos-defaults     Apply personal macOS System Settings/Finder/Dock defaults.
  -h, --help           Show this help.
EOF
}

run_brew=true
run_pipx=false
pipx_args=()
apply_macos_defaults=false
dry_run=false
migration_needed=false
stow_only=false

resolve_brewfile() {
  local requested="$1"

  if [[ "${requested}" = /* ]]; then
    BREWFILE="${requested}"
  else
    BREWFILE="${DOTFILES_DIR}/${requested}"
  fi
}

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"

  if [[ -d "${target_dir}/.git" ]]; then
    ui_info "Already cloned; checking for fast-forward updates: ${target_dir}"
    git -C "${target_dir}" pull --ff-only
  elif [[ -e "${target_dir}" ]]; then
    echo "Skipping ${target_dir}; it already exists and is not a Git checkout." >&2
  else
    ui_info "Cloning missing dependency: ${target_dir}"
    git clone "${repo_url}" "${target_dir}"
  fi
}

link_points_to_source() {
  local target_path="$1"
  local source_path="$2"

  [[ -e "${target_path}" && "${target_path}" -ef "${source_path}" ]]
}

# A minimal lexical ../. resolver (no filesystem access, so it also works on
# dangling symlink targets that realpath/readlink -f can't resolve) used to
# compare a stale link's target against this checkout's path.
normalize_path_lexically() {
  local input="$1"
  local part
  local -a input_parts output_parts

  IFS='/' read -r -a input_parts <<< "${input}"
  for part in "${input_parts[@]}"; do
    case "${part}" in
      ''|.) ;;
      ..)
        if [[ "${#output_parts[@]}" -gt 0 ]]; then
          unset 'output_parts[${#output_parts[@]}-1]'
        fi
        ;;
      *) output_parts+=("${part}") ;;
    esac
  done

  printf '/'
  local IFS='/'
  printf '%s' "${output_parts[*]}"
}

# A candidate root is "managed" if it matches the root recorded by a
# previous install (STOW_ROOT_FILE), so links created before a checkout moved
# are still recognized.
previous_root_is_managed() {
  local candidate="$1"
  local recorded_root=''

  [[ -f "${STOW_ROOT_FILE}" ]] && IFS= read -r recorded_root < "${STOW_ROOT_FILE}"

  [[ -n "${recorded_root}" && "${candidate}" == "${recorded_root}" ]]
}

# Determines whether an existing symlink was created by a *previous* checkout
# of this same package (e.g. before the repo moved) rather than by something
# unrelated, by checking that its target still ends in the expected
# "<package>/<relative_path>" suffix and that the root before that suffix is
# a recognized prior checkout. Only such links are safe to remove and replace.
link_belongs_to_previous_checkout() {
  local link_target="$1"
  local package="$2"
  local relative_path="$3"
  local target_path="$4"
  local absolute_target suffix previous_root

  if [[ "${link_target}" = /* ]]; then
    absolute_target="$(normalize_path_lexically "${link_target}")"
  else
    absolute_target="$(normalize_path_lexically "$(dirname "${target_path}")/${link_target}")"
  fi

  suffix="/${package}/${relative_path}"
  case "${absolute_target}" in
    *"${suffix}") previous_root="${absolute_target%"${suffix}"}" ;;
    *) return 1 ;;
  esac

  previous_root_is_managed "${previous_root}"
}

record_stow_root() {
  mkdir -p "${STOW_STATE_DIR}"
  if [[ ! -f "${STOW_ROOT_FILE}" || "$(<"${STOW_ROOT_FILE}")" != "${DOTFILES_DIR}" ]]; then
    printf '%s\n' "${DOTFILES_DIR}" > "${STOW_ROOT_FILE}"
  fi
}

# Finds symlinks left behind by a prior checkout of this repo (e.g. it was
# deleted and re-cloned to a new path) and removes just those, so stow can
# relink them from the current checkout instead of refusing to touch a path
# it doesn't recognize as its own.
migrate_stale_symlinks() {
  local package source_path relative_path target_path link_target

  for package in "${STOW_PACKAGES[@]}"; do
    while IFS= read -r -d '' source_path; do
      relative_path="${source_path#"${DOTFILES_DIR}/${package}/"}"
      target_path="${STOW_TARGET}/${relative_path}"

      [[ -L "${target_path}" ]] || continue
      link_points_to_source "${target_path}" "${source_path}" && continue

      link_target="$(readlink "${target_path}")"
      link_belongs_to_previous_checkout "${link_target}" "${package}" "${relative_path}" "${target_path}" || continue

      if [[ "${dry_run}" == true ]]; then
        migration_needed=true
        printf 'Would migrate stale symlink: %s -> %s\n' "${target_path}" "${link_target}"
      else
        printf 'Migrating stale symlink: %s -> %s\n' "${target_path}" "${link_target}"
        rm "${target_path}"
      fi
    done < <(find "${DOTFILES_DIR}/${package}" -mindepth 1 -print0)
  done
}

trust_required_homebrew_taps() {
  mkdir -p "${XDG_CONFIG_HOME}/homebrew"
  brew trust --tap felixkratz/formulae
  brew trust --tap nikitabobko/tap
}

# Stow refuses to link over a real file, so an untracked ~/.gitconfig (e.g.
# from a first-time Git install) is moved aside rather than overwritten or
# left blocking the install.
backup_existing_gitconfig() {
  local target="${HOME}/.gitconfig"
  local managed_source="${DOTFILES_DIR}/git/.gitconfig"
  local backup_dir backup

  [[ -f "${target}" && ! -L "${target}" ]] || return 0
  link_points_to_source "${target}" "${managed_source}" && return

  backup_dir="${STOW_STATE_DIR}/backups"
  backup="${backup_dir}/gitconfig.$(date +%Y%m%d-%H%M%S)"
  [[ ! -e "${backup}" ]] || backup="${backup}.$$"
  mkdir -p "${backup_dir}"
  mv "${target}" "${backup}"
  ui_info "Preserved existing ~/.gitconfig at ${backup}"
}

install_default_node() {
  if ! command -v brew >/dev/null 2>&1; then
    return
  fi

  local nvm_prefix
  nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
  if [[ -z "${nvm_prefix}" || ! -s "${nvm_prefix}/nvm.sh" ]]; then
    return
  fi

  export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
  # shellcheck source=/dev/null
  . "${nvm_prefix}/nvm.sh"

  if [[ "$(nvm version "${DEFAULT_NODE_VERSION}" 2>/dev/null)" == "N/A" ]]; then
    nvm install "${DEFAULT_NODE_VERSION}"
  else
    ui_skip "Node ${DEFAULT_NODE_VERSION} is already installed"
  fi
  nvm alias default "${DEFAULT_NODE_VERSION}"
}

install_pyenv_pythons() {
  if ! command -v pyenv >/dev/null 2>&1; then
    echo "pyenv is not installed; skipping Python runtime install." >&2
    return
  fi

  export PYENV_ROOT="${XDG_CONFIG_HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"

  local version
  for version in ${PYENV_PYTHON_VERSIONS}; do
    if [[ -d "${PYENV_ROOT}/versions/${version}" ]]; then
      ui_skip "Python ${version} is already installed"
    else
      pyenv install "${version}"
    fi
  done

  pyenv global ${PYENV_GLOBAL_VERSIONS}
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adopt)
      STOW_FLAGS+=(--adopt)
      ;;
    --dry-run)
      dry_run=true
      ;;
    --stow-only)
      stow_only=true
      ;;
    --no-brew)
      run_brew=false
      ;;
    --essential)
      BREWFILE="${DOTFILES_DIR}/Brewfile-essential"
      ;;
    --full)
      BREWFILE="${DOTFILES_DIR}/Brewfile"
      ;;
    --brewfile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--brewfile requires a file path or Brewfile name." >&2
        exit 1
      fi
      resolve_brewfile "$1"
      ;;
    --brewfile=*)
      resolve_brewfile "${1#*=}"
      ;;
    --pipx)
      run_pipx=true
      ;;
    --pipxfile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--pipxfile requires a file path or Pipxfile name." >&2
        exit 1
      fi
      run_pipx=true
      pipx_args+=(--pipxfile "$1")
      ;;
    --pipxfile=*)
      run_pipx=true
      pipx_args+=("--pipxfile=${1#*=}")
      ;;
    --macos-defaults)
      apply_macos_defaults=true
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

if [[ "${dry_run}" == true ]]; then
  ui_init 1 "Dotfiles installation dry run"
  ui_stage "Inspecting managed symlinks"
  migrate_stale_symlinks
  if [[ "${migration_needed}" == true ]]; then
    # Simulating stow while stale links still exist would report them as
    # conflicts rather than as the pending migration they actually are, so
    # skip the simulation and point at the fix instead.
    echo "Stow simulation skipped because the stale links above still exist during a dry run."
    echo "Run ./install.sh --stow-only to migrate them, then --dry-run will verify the final state."
  else
    stow "${STOW_FLAGS[@]}" --simulate "${STOW_PACKAGES[@]}"
  fi
  ui_complete "Dry run complete"
  exit 0
fi

if [[ "${stow_only}" == true ]]; then
  ui_init 1 "Dotfiles link installation"
  ui_stage "Migrating and restowing managed symlinks"
  mkdir -p "${STOW_STATE_DIR}"
  backup_existing_gitconfig
  migrate_stale_symlinks
  stow "${STOW_FLAGS[@]}" "${STOW_PACKAGES[@]}"
  record_stow_root
  ui_done "Managed symlinks are current"
  ui_complete "Dotfile symlinks now point to ${DOTFILES_DIR}"
  exit 0
fi

# Stage count drives the progress UI's "stage N of TOTAL" output, so it must
# be computed from the same conditions used below to decide which stages
# actually run.
install_stage_total=5
[[ "${run_brew}" == true ]] && install_stage_total=$((install_stage_total + 1))
[[ "${run_pipx}" == true ]] && install_stage_total=$((install_stage_total + 1))
[[ "${apply_macos_defaults}" == true ]] && install_stage_total=$((install_stage_total + 1))
ui_init "${install_stage_total}" "Dotfiles installation"

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-"${HOME}/.cache"}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-"${HOME}/.local/share"}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-"${HOME}/.local/state"}"

ui_stage "Preparing XDG and application directories"
mkdir -p \
  "${XDG_CACHE_HOME}" \
  "${XDG_CONFIG_HOME}/nvm" \
  "${XDG_CONFIG_HOME}/zsh" \
  "${XDG_DATA_HOME}" \
  "${XDG_STATE_HOME}" \
  "${XDG_CACHE_HOME}/zsh" \
  "${HOME}/.local/bin"
ui_done "Directories are ready"

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [[ "${run_brew}" == true ]]; then
  ui_stage "Installing missing Homebrew dependencies"
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Install Homebrew first, then rerun ./install.sh." >&2
    exit 1
  fi

  if [[ ! -f "${BREWFILE}" ]]; then
    echo "Brewfile not found: ${BREWFILE}" >&2
    exit 1
  fi

  trust_required_homebrew_taps

  ui_info "Using ${BREWFILE}"
  "${SCRIPTS_DIR}/install-brew-bundle.sh" "${BREWFILE}"
  ui_done "Homebrew dependencies are satisfied"
fi

ui_stage "Ensuring the default Node runtime"
install_default_node
ui_done "Node runtime is ready"

ui_stage "Ensuring configured Python runtimes"
install_pyenv_pythons
ui_done "Python runtimes are ready"

ui_stage "Ensuring shell dependencies"
clone_or_update "https://github.com/ohmyzsh/ohmyzsh.git" "${XDG_CONFIG_HOME}/oh-my-zsh"
ui_done "External Git dependencies are ready"

ui_stage "Migrating and restowing managed symlinks"
backup_existing_gitconfig
migrate_stale_symlinks
stow "${STOW_FLAGS[@]}" "${STOW_PACKAGES[@]}"
record_stow_root
ui_done "Managed symlinks are current"

if [[ "${run_pipx}" == true ]]; then
  ui_stage "Installing missing pipx applications"
  "${SCRIPTS_DIR}/install-pipx.sh" "${pipx_args[@]}"
  ui_done "pipx applications are satisfied"
fi

if [[ "${apply_macos_defaults}" == true ]]; then
  ui_stage "Applying macOS defaults"
  "${SCRIPTS_DIR}/macos-defaults.sh" --yes
  ui_done "macOS defaults applied"
fi

ui_complete "Dotfiles installation complete"

cat <<'EOF'

Dotfiles installed.

Recommended manual follow-up:
  1. Restart your terminal.
  2. Open AeroSpace once and grant macOS permissions if prompted.
  3. Install optional toolsDots components directly or through intelliDots/install.sh.
EOF
