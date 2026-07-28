#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
# Read-only VCS state adapter for consumer projects.

PROJECT_VCS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_VCS_LIB_DIR/project-runtime.sh"

_bp_jj_snapshot_identity() {
  local project_root="$1" change_id parent_bookmark
  change_id="$(jj --no-pager -R "$project_root" log -r '@' --no-graph \
    -T 'change_id.short()' 2>/dev/null || true)"
  parent_bookmark="$(jj --no-pager -R "$project_root" log \
    -r 'latest(ancestors(@) & bookmarks(), 1)' --no-graph \
    -T 'bookmarks' 2>/dev/null || true)"
  printf 'identity_label=Change ID\nidentity=%s\nparent_bookmark=%s\n' \
    "$change_id" "$parent_bookmark"
}

bp_vcs_snapshot() {
  local project_root="${1:-$PWD}" vcs_kind
  vcs_kind="$(bp_vcs_kind "$project_root")" || return
  printf 'kind=%s\n' "$vcs_kind"
  [[ "$vcs_kind" == jj ]] && _bp_jj_snapshot_identity "$project_root"
}
