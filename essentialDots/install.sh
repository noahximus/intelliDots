#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${DOTFILES_DIR}/scripts"
# shellcheck source=scripts/lib/progress.sh
. "${SCRIPTS_DIR}/lib/progress.sh"
# Stale-symlink migration is shared with every other stow-using component, so
# a moved checkout is relinked the same way everywhere rather than only here.
# shellcheck source=scripts/lib/stow-migrate.sh
. "${SCRIPTS_DIR}/lib/stow-migrate.sh"
# Reports which numbered stage failed rather than a bare non-zero exit,
# since this installer runs many stages and the stage number alone
# localizes the failure without needing -x tracing.
trap 'ui_fail "Dotfiles installation stopped during stage ${UI_STEP:-0} of ${UI_TOTAL:-0}"' ERR
DEFAULT_NODE_VERSION="${DEFAULT_NODE_VERSION:-22.7.0}"
PYENV_PYTHON_VERSIONS="${PYENV_PYTHON_VERSIONS:-3.10.19 3.11.14 3.12.12 3.13.14 3.14.6}"
PYENV_GLOBAL_VERSIONS="${PYENV_GLOBAL_VERSIONS:-3.14.6 3.13.14 3.12.12 3.11.14 3.10.19 system}"
STOW_TARGET="${HOME}"
# This component's config spans tiers: the shell and Git belong on every
# machine, the window-manager config only where the macOS desktop tier is
# installed, and the Python config only on a development machine. Grouping
# the stow packages by owning tier is what stops an `air` machine from
# linking python/ and btop/ config for tools it never installed.
ALL_STOW_PACKAGES=(zsh local git python aerospace borders btop)
stow_packages_for_tier() {
  case "$1" in
    core)           printf '%s\n' zsh local git ;;
    mac-essentials) printf '%s\n' aerospace borders ;;
    mac-extras)     printf '%s\n' btop ;;
    dev-essentials) printf '%s\n' python ;;
    *) ;;
  esac
}
declare -a cli_tiers=()
declare -a STOW_PACKAGES=()
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${DOTFILES_DIR}" --target="${STOW_TARGET}" --verbose --restow --no-folding)

usage() {
  cat <<'EOF'
Usage: ./install.sh [--adopt] [--dry-run] [--stow-only] [--pipx] [--pipxfile FILE|NAME] [--macos-defaults]

Installs this component's configuration. Packages are NOT installed here --
they are declared in the repository's tier Brewfiles under tiers/ and
installed once by the root install.sh.

Options:
  --adopt              Let stow adopt existing files into this repo before linking.
                       Use this only when you intentionally want to absorb local files.
  --dry-run            Show stale symlinks that would be migrated and simulate Stow.
                       No packages, runtimes, or configuration are changed.
  --stow-only          Migrate and restow dotfile links without installing anything else.
  --no-brew            Accepted for compatibility; this component installs no packages.
  --essential          Accepted for compatibility; no longer selects a Brewfile.
  --full               Accepted for compatibility; no longer selects a Brewfile.
  --brewfile FILE|NAME Accepted and ignored; use the root install.sh's --tier/--pick.
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
stow_only=false

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

# Route a pyenv build at the correct Homebrew Tcl/Tk so python-build compiles the
# _tkinter extension (tkinter). Without a Tcl/Tk library at build time python-build
# silently omits tkinter and `import tkinter` fails. CPython 3.10-3.12 target Tk 8.6
# (tcl-tk@8); 3.13+ support the latest Tk 9.x (tcl-tk). The two formulae coexist
# without conflict: tcl-tk@8 is keg-only (isolated under its own opt prefix) and
# tcl-tk 9 only collides with the unrelated `page`/`the_platinum_searcher` binaries.
#
# The library version suffix (e.g. 8.6 or 9.0) is read from the installed dylib so
# it tracks Homebrew bumps. PYTHON_CONFIGURE_OPTS/PKG_CONFIG_PATH are set fresh on
# every call so a build never inherits the previous version's Tcl/Tk. Sets
# PYENV_TCLTK_LABEL for logging. Returns 0 when configured, 1 when the required
# formula is missing (then builds proceed without tkinter after a warning). Keep the
# selection rule in sync with zsh/apps/pythonrc, which does the same for manual installs.
pyenv_tcltk_configure() {
  local version="$1" minor formula prefix lib suffix
  unset PYTHON_CONFIGURE_OPTS PKG_CONFIG_PATH
  PYENV_TCLTK_LABEL=""

  minor="${version#*.}"; minor="${minor%%.*}"
  if [[ "${minor}" =~ ^[0-9]+$ ]] && (( minor >= 13 )); then
    formula="tcl-tk"      # Tk 9.x (latest)
  else
    formula="tcl-tk@8"    # Tk 8.6
  fi

  prefix="$(brew --prefix "${formula}" 2>/dev/null || true)"
  if [[ -z "${prefix}" || ! -d "${prefix}" ]]; then
    ui_warn "${formula} not found via brew; Python ${version} will be built WITHOUT tkinter. Run: brew install ${formula}"
    return 1
  fi

  lib="$(ls "${prefix}"/lib/libtcl[0-9]*.dylib 2>/dev/null | head -1)"
  if [[ -z "${lib}" ]]; then
    ui_warn "No Tcl library under ${prefix}/lib; Python ${version} will be built WITHOUT tkinter."
    return 1
  fi
  suffix="${lib##*/libtcl}"; suffix="${suffix%.dylib}"   # e.g. 9.0 or 8.6

  export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig"
  export PYTHON_CONFIGURE_OPTS="--with-tcltk-includes='-I${prefix}/include' --with-tcltk-libs='-L${prefix}/lib -ltcl${suffix} -ltk${suffix}'"
  PYENV_TCLTK_LABEL="${formula} (Tk ${suffix})"
  return 0
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
      # Self-heal machines whose Python predates the tcl-tk wiring: if the
      # interpreter exists but has no working _tkinter, rebuild it in place.
      if pyenv_tcltk_configure "${version}" \
        && ! "${PYENV_ROOT}/versions/${version}/bin/python" -c "import _tkinter" >/dev/null 2>&1; then
        ui_info "Python ${version} lacks tkinter; rebuilding against ${PYENV_TCLTK_LABEL}"
        pyenv install -f "${version}"
      else
        ui_skip "Python ${version} is already installed"
      fi
    else
      pyenv_tcltk_configure "${version}" || true
      pyenv install "${version}"
    fi
  done

  # Don't leak the last version's Tcl/Tk build flags into later install stages.
  unset PYTHON_CONFIGURE_OPTS PKG_CONFIG_PATH

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
    --tier)
      shift
      [[ $# -gt 0 ]] || { echo "--tier requires a name" >&2; exit 1; }
      cli_tiers+=("$1")
      ;;
    --tier=*)
      cli_tiers+=("${1#*=}")
      ;;
    --no-brew)
      run_brew=false
      ;;
    # Profile flags are accepted so the root installer can pass them uniformly,
    # but they no longer select a Brewfile: packages come from tiers/.
    --essential)
      ;;
    --full)
      ;;
    # Accepted and ignored: package selection moved to the repository's tier
    # Brewfiles. Use the root install.sh's --tier / --pick instead.
    --brewfile)
      shift
      [[ $# -gt 0 ]] || { echo "--brewfile requires a file path or Brewfile name." >&2; exit 1; }
      echo "Note: --brewfile is ignored; packages come from tiers/." >&2
      ;;
    --brewfile=*)
      echo "Note: --brewfile is ignored; packages come from tiers/." >&2
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

# No --tier means a standalone run of this component, which keeps the old
# behavior of stowing everything. The root install.sh always passes the
# profile's tiers, so a profile-driven install links only what it selected.
if [[ "${#cli_tiers[@]}" -eq 0 ]]; then
  STOW_PACKAGES=("${ALL_STOW_PACKAGES[@]}")
else
  for tier in "${cli_tiers[@]}"; do
    while IFS= read -r stow_package; do
      [[ -n "${stow_package}" ]] || continue
      STOW_PACKAGES+=("${stow_package}")
    done < <(stow_packages_for_tier "${tier}")
  done
fi

if [[ "${#STOW_PACKAGES[@]}" -eq 0 ]]; then
  echo "No stow packages for tiers: ${cli_tiers[*]}" >&2
  exit 1
fi

if [[ "${dry_run}" == true ]]; then
  ui_init 1 "Dotfiles installation dry run"
  ui_stage "Inspecting managed symlinks"
  STOW_MIGRATE_DRY_RUN=true stow_migrate "${DOTFILES_DIR}" "${STOW_TARGET}" "${STOW_PACKAGES[@]}"
  if [[ "${STOW_MIGRATED_COUNT:-0}" -gt 0 ]]; then
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
  stow_migrate "${DOTFILES_DIR}" "${STOW_TARGET}" "${STOW_PACKAGES[@]}"
  stow "${STOW_FLAGS[@]}" "${STOW_PACKAGES[@]}"
  ui_done "Managed symlinks are current"
  ui_complete "Dotfile symlinks now point to ${DOTFILES_DIR}"
  exit 0
fi

# Stage count drives the progress UI's "stage N of TOTAL" output, so it must
# be computed from the same conditions used below to decide which stages
# actually run.
install_stage_total=5
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
  ui_info "This component no longer installs its own packages."
  ui_info "Run the repository's root install.sh to install from tiers/."
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
stow_migrate "${DOTFILES_DIR}" "${STOW_TARGET}" "${STOW_PACKAGES[@]}"
stow "${STOW_FLAGS[@]}" "${STOW_PACKAGES[@]}"
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
