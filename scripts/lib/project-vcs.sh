#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
# Read-only VCS state adapter for consumer projects.

PROJECT_VCS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_VCS_LIB_DIR/project-runtime.sh"

bp_vcs_snapshot() {
  local project_root="${1:-$PWD}"
  printf 'kind=%s\n' "$(bp_vcs_kind "$project_root")"
}
