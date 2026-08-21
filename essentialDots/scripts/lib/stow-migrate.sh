#!/usr/bin/env bash

# Shared stale-symlink migration for every stow-using component.
#
# Stow refuses to touch a symlink it does not recognize as its own, so when a
# checkout moves -- or a second one appears at a new path -- every previously
# linked file becomes "existing target is not owned by stow" and the whole
# node aborts. This lived only in essentialDots, which is why moving a
# checkout used to leave the toolsDots nodes stuck with no way forward but a
# manual find-and-rm.
#
# Two things it fixes over the original:
#
#   * Every node calls it, not just essentialDots.
#   * A link is recognized as ours when its target resolves inside *any*
#     intelliDots checkout at the matching node/package/relative-path, which
#     is verified by walking up to a features.yaml rather than by string
#     match. The old version compared against a single recorded root, so the
#     moment it migrated once and rewrote that record, links left over from
#     the earlier location stopped being recognizable at all.
#
# The recorded-roots file remains as a fallback for the case the lib cannot
# verify on its own: an old checkout that has since been deleted, whose links
# still point into thin air.

STOW_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/intelliDots"
STOW_ROOTS_FILE="${STOW_STATE_DIR}/stow-roots"
# essentialDots kept a single root here before this was shared.
STOW_LEGACY_ROOT_FILE="${XDG_STATE_HOME:-${HOME}/.local/state}/essentialDots/stow-root"

# True when a path already resolves to the given source file, symlink chain
# and all. Used both to skip links that are already correct and, by callers,
# to tell a managed file from a real one.
link_points_to_source() {
  local target_path="$1" source_path="$2"
  [[ -e "${target_path}" && "${target_path}" -ef "${source_path}" ]]
}

# A minimal lexical ../. resolver. It does no filesystem access, so it also
# works on dangling targets that realpath/readlink -f cannot resolve -- which
# is exactly the case when the old checkout is gone.
stow_normalize_path() {
  local input="$1" part
  local -a input_parts output_parts

  IFS='/' read -r -a input_parts <<< "${input}"
  for part in "${input_parts[@]}"; do
    case "${part}" in
      '' | .) ;;
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

# Walks up from a directory to the intelliDots checkout containing it,
# identified by features.yaml. This is what lets a node discover its own
# repository root without every caller hardcoding how deep it sits.
stow_repo_root() {
  local dir="$1"
  while [[ "${dir}" != "/" && -n "${dir}" ]]; do
    if [[ -f "${dir}/features.yaml" ]]; then
      printf '%s' "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

stow_known_roots() {
  [[ -f "${STOW_LEGACY_ROOT_FILE}" ]] && sed 's|/essentialDots$||' "${STOW_LEGACY_ROOT_FILE}"
  [[ -f "${STOW_ROOTS_FILE}" ]] && cat "${STOW_ROOTS_FILE}"
  return 0
}

# Roots accumulate rather than replace. A machine that has moved its checkout
# twice can still recognize links from either earlier location.
stow_record_root() {
  local root="$1" known
  mkdir -p "${STOW_STATE_DIR}"
  while IFS= read -r known; do
    [[ "${known}" == "${root}" ]] && return 0
  done < <(stow_known_roots)
  printf '%s\n' "${root}" >>"${STOW_ROOTS_FILE}"
}

# True when an existing symlink was created by some checkout of this same
# component -- its target ends in the expected "<node>/<package>/<relative>"
# and the directory before that is a real intelliDots checkout, or one this
# machine has recorded. Anything else is left alone for stow to complain
# about, which is the correct outcome for a genuinely foreign file.
stow_link_is_ours() {
  local absolute_target="$1" node_relpath="$2" package="$3" relative_path="$4"
  local suffix candidate_root known

  suffix="/${node_relpath}/${package}/${relative_path}"
  case "${absolute_target}" in
    *"${suffix}") candidate_root="${absolute_target%"${suffix}"}" ;;
    *) return 1 ;;
  esac

  # Preferred test: the prefix really is a checkout, on disk, right now.
  [[ -f "${candidate_root}/features.yaml" ]] && return 0

  # Fallback for a checkout that has since been deleted.
  while IFS= read -r known; do
    [[ -n "${known}" && "${known}" == "${candidate_root}" ]] && return 0
  done < <(stow_known_roots)
  return 1
}

# Removes links left by another checkout so stow can relink them from this
# one. Prints what it does; honours STOW_MIGRATE_DRY_RUN=true.
#
# Sets STOW_MIGRATED_COUNT to the number of links handled. Callers use it to
# tell "nothing to do" from "work pending": simulating stow while stale links
# are still on disk reports them as conflicts rather than as the migration
# they actually are.
#
#   stow_migrate <stow_dir> <target_dir> <package>...
stow_migrate() {
  local stow_dir="$1" target_dir="$2"
  shift 2
  STOW_MIGRATED_COUNT=0
  local repo_root node_relpath package source_path relative_path target_path
  local link_target absolute_target

  repo_root="$(stow_repo_root "${stow_dir}")" || {
    echo "Not inside an intelliDots checkout: ${stow_dir}" >&2
    return 1
  }
  stow_record_root "${repo_root}"

  # "toolsDots/devTools/iTerm", or "essentialDots" -- the component's path
  # within the checkout, which is the part a stale link shares with this one.
  node_relpath="${stow_dir#"${repo_root}/"}"
  [[ "${node_relpath}" != "${stow_dir}" ]] || node_relpath=""

  for package in "$@"; do
    [[ -d "${stow_dir}/${package}" ]] || continue
    while IFS= read -r -d '' source_path; do
      relative_path="${source_path#"${stow_dir}/${package}/"}"
      target_path="${target_dir}/${relative_path}"

      [[ -L "${target_path}" ]] || continue
      [[ -e "${target_path}" && "${target_path}" -ef "${source_path}" ]] && continue

      link_target="$(readlink "${target_path}")"
      if [[ "${link_target}" = /* ]]; then
        absolute_target="$(stow_normalize_path "${link_target}")"
      else
        absolute_target="$(stow_normalize_path "$(dirname "${target_path}")/${link_target}")"
      fi

      stow_link_is_ours "${absolute_target}" "${node_relpath}" "${package}" "${relative_path}" || continue

      STOW_MIGRATED_COUNT=$((STOW_MIGRATED_COUNT + 1))
      if [[ "${STOW_MIGRATE_DRY_RUN:-false}" == true ]]; then
        printf 'Would migrate stale symlink: %s -> %s\n' "${target_path}" "${link_target}"
      else
        printf 'Migrating stale symlink: %s -> %s\n' "${target_path}" "${link_target}"
        rm "${target_path}"
      fi
    done < <(find "${stow_dir}/${package}" -mindepth 1 -print0)
  done
}
