#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
# scenario: SC-e81s03-P0-02
# scenario: SC-e81s03-P0-03
# scenario: SC-e81s03-P1-01
# Read-only VCS state adapter for consumer projects.

PROJECT_VCS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_VCS_LIB_DIR/project-runtime.sh"

_bp_jj_snapshot() {
  local project_root="$1" change_id parent_bookmark status recent_logs
  change_id="$(jj --no-pager -R "$project_root" log -r '@' --no-graph \
    -T 'change_id.short()' 2>/dev/null || true)"
  parent_bookmark="$(jj --no-pager -R "$project_root" log \
    -r 'latest(ancestors(@) & bookmarks(), 1)' --no-graph \
    -T 'bookmarks' 2>/dev/null || true)"
  status="$(jj --no-pager -R "$project_root" status 2>/dev/null | tr '\n' ' ')"
  recent_logs="$(jj --no-pager -R "$project_root" log -n 3 --no-graph \
    -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' \
    2>/dev/null | tr '\n' ' ')"
  printf 'identity_label=Change ID\nidentity=%s\nparent_bookmark=%s\nstatus=%s\nrecent_logs=%s\n' \
    "$change_id" "$parent_bookmark" "$status" "$recent_logs"
}

_bp_git_snapshot() {
  local project_root="$1" branch status recent_logs
  branch="$(git -C "$project_root" branch --show-current 2>/dev/null)"
  status="$(git -C "$project_root" status --short 2>/dev/null \
    | head -n 5 | tr '\n' ' ')"
  recent_logs="$(git -C "$project_root" log --oneline -3 2>/dev/null \
    | tr '\n' ' ')"
  printf 'branch=%s\nstatus=%s\nrecent_logs=%s\n' \
    "$branch" "$status" "$recent_logs"
}

_bp_validate_explicit_vcs() {
  local project_root="$1" vcs_kind="$2" configured_vcs
  configured_vcs="$(_bp_vcs_value "$project_root")" || return
  [[ "$configured_vcs" == auto ]] && return 0

  if ! command -v "$vcs_kind" >/dev/null 2>&1; then
    echo "bigpowers VCS: selected '$vcs_kind' but its executable is missing; install $vcs_kind or select vcs: auto" >&2
    return 2
  fi
  if [[ "$vcs_kind" == jj ]] && ! jj --no-pager -R "$project_root" root >/dev/null 2>&1; then
    echo "bigpowers VCS: selected 'jj' for '$project_root', but it is not a Jujutsu repository; initialize Jujutsu or select vcs: auto" >&2
    return 2
  fi
  if [[ "$vcs_kind" == git ]] && ! git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "bigpowers VCS: selected 'git' for '$project_root', but it is not a Git repository; initialize Git or select vcs: auto" >&2
    return 2
  fi
}

bp_vcs_snapshot() {
  local project_root="${1:-$PWD}" vcs_kind
  vcs_kind="$(bp_vcs_kind "$project_root")" || return
  _bp_validate_explicit_vcs "$project_root" "$vcs_kind" || return
  printf 'kind=%s\n' "$vcs_kind"
  case "$vcs_kind" in
    jj) _bp_jj_snapshot "$project_root" ;;
    git) _bp_git_snapshot "$project_root" ;;
  esac
}
