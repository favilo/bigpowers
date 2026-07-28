#!/usr/bin/env bash
# project-survey.sh — automated project status for session-start hooks

set -euo pipefail

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_LIB_DIR/project-runtime.sh"
PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
SPECS_DIR="$(bp_specs_path "$PROJECT_ROOT" "")"

# 1. Gather file existence info
has_conventions=$([[ -f "$PROJECT_ROOT/CONVENTIONS.md" ]] && echo "true" || echo "false")
has_claude=$([[ -f "$PROJECT_ROOT/CLAUDE.md" ]] && echo "true" || echo "false")
has_specs=$([[ -d "$SPECS_DIR" ]] && echo "true" || echo "false")

# 2. Scan the configured artifact root (YAML-first)
specs_files=""
if [[ "$has_specs" == "true" ]]; then
  specs_files=$( {
    ls "$SPECS_DIR"/*.yaml 2>/dev/null || true
    ls "$SPECS_DIR"/product/*.yaml 2>/dev/null || true
    ls "$SPECS_DIR"/*.md 2>/dev/null || true
  } | xargs -n1 basename 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
fi

# 3. Git state (replaced by the VCS adapter in the Jujutsu slice)
current_branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "not-a-repo")
git_status=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null | head -n 5 | tr '\n' ' ' | sed 's/"/\\"/g' || true)
recent_logs=$(git -C "$PROJECT_ROOT" log --oneline -3 2>/dev/null | tr '\n' ' ' | sed 's/"/\\"/g' || true)

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
Branch: $current_branch
Files: CONVENTIONS=$has_conventions, CLAUDE=$has_claude, SPECS=$has_specs
Specs Found: $specs_files
Git Status: $git_status
Recent Logs: $recent_logs

Welcome to Bigpowers. I have analyzed the project state. 
You are currently in the '$phase' phase on the '$current_branch' branch.
EOF

if [[ -f "$SPECS_DIR/release-plan.yaml" ]]; then
  echo "release-plan.yaml found. Read $SPECS_DIR/state.yaml for active epic/story."
fi
