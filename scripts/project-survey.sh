#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P1-02
# project-survey.sh — automated project status for session-start hooks

set -euo pipefail

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_LIB_DIR/project-vcs.sh"
PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
SPECS_DIR="$(bp_specs_path "$PROJECT_ROOT" "")"

# 1. Gather file existence info
has_conventions=$([[ -f "$PROJECT_ROOT/CONVENTIONS.md" ]] && echo "true" || echo "false")
has_claude=$([[ -f "$PROJECT_ROOT/CLAUDE.md" ]] && echo "true" || echo "false")
has_specs=$([[ -d "$SPECS_DIR" ]] && echo "true" || echo "false")

# 2. Scan the configured artifact root (YAML-first)
specs_files=""
if [[ "$has_specs" == "true" ]]; then
  shopt -s nullglob
  spec_paths=(
    "$SPECS_DIR"/*.yaml
    "$SPECS_DIR"/product/*.yaml
    "$SPECS_DIR"/*.md
  )
  shopt -u nullglob
  # bash 3.2 + set -u: empty array expansion is unbound without the + guard
  specs_files=$(for spec_path in ${spec_paths[@]+"${spec_paths[@]}"}; do
    basename "$spec_path"
  done | sort -u | tr '\n' ',' | sed 's/,$//')
fi

# 3. VCS state
vcs_snapshot="$(bp_vcs_snapshot "$PROJECT_ROOT")"
vcs_value() {
  local key="$1"
  printf '%s\n' "$vcs_snapshot" | sed -n "s/^${key}=//p"
}
vcs_kind="$(vcs_value kind)"
current_branch="$(vcs_value branch)"
change_id="$(vcs_value identity)"
parent_bookmark="$(vcs_value parent_bookmark)"
vcs_status="$(vcs_value status)"
recent_logs="$(vcs_value recent_logs)"

# 4. Phase mapping logic (YAML-first)
phase="Discover"
if [[ -f "$SPECS_DIR/state.yaml" ]]; then
  flow=$(grep -E '^active_flow:' "$SPECS_DIR/state.yaml" | sed 's/active_flow:[[:space:]]*//')
  case "$flow" in
    fix_bug) phase="Bug" ;;
    build_epic) phase="Execute" ;;
    planning) phase="Plan" ;;
  esac
elif [[ -f "$SPECS_DIR/release-plan.yaml" ]]; then
  phase="Plan"
elif [[ -f "$SPECS_DIR/product/SCOPE_LATEST.yaml" ]] || [[ -f "$SPECS_DIR/SCOPE.md" ]]; then
  phase="Design"
elif [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
  phase="Initiate"
fi

if [[ -f "$SPECS_DIR/DIAGNOSIS.md" ]]; then
  phase="Bug"
fi

# 5. Output concise text for context injection
cat <<EOF
[PROJECT SURVEY]
Phase: $phase
VCS: $vcs_kind
Files: CONVENTIONS=$has_conventions, CLAUDE=$has_claude, SPECS=$has_specs
Specs Found: $specs_files
VCS Status: $vcs_status
Recent Logs: $recent_logs
EOF

if [[ "$vcs_kind" == jj ]]; then
  echo "Change ID: $change_id"
  echo "Parent Bookmark: $parent_bookmark"
else
  echo "Branch: $current_branch"
fi

echo
printf "Welcome to Bigpowers. I have analyzed the project state.\n"
printf "You are currently in the '%s' phase using '%s'.\n" "$phase" "$vcs_kind"

if [[ -f "$SPECS_DIR/release-plan.yaml" ]]; then
  echo "release-plan.yaml found. Read $SPECS_DIR/state.yaml for active epic/story."
fi
