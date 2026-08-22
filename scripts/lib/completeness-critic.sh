#!/usr/bin/env bash
# story: e45s05 e53s01
# Adversarial gap-finding completeness critic — post gate-trace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-runtime.sh"
PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)" || {
  echo "completeness-critic: project root not found: ${BIGPOWERS_PROJECT_ROOT:-$PWD}" >&2
  exit 1
}
SPECS_ROOT="$(bp_specs_path "$PROJECT_ROOT" "")" || exit 1

# Classifications: BLOCKER | WARNING | FILLED
BLOCKERS=0
WARNINGS=0
FILLED=0
classify() {
  local kind="$1" msg="$2"
  echo "[$kind] $msg"
  case "$kind" in
    BLOCKER) BLOCKERS=$((BLOCKERS + 1)) ;;
    WARNING) WARNINGS=$((WARNINGS + 1)) ;;
    FILLED) FILLED=$((FILLED + 1)) ;;
  esac
}

# Ensure upstream artifacts exist in the resolved consumer project.
MATRIX="$SPECS_ROOT/traceability-matrix.json"
BLIND_SPOTS="$SPECS_ROOT/blind-spots.json"
STATE="$SPECS_ROOT/state.yaml"
[[ -f "$MATRIX" ]] || classify BLOCKER "Missing $MATRIX — run trace-stories.sh --json"
[[ -f "$BLIND_SPOTS" ]] || classify BLOCKER "Missing $BLIND_SPOTS — run check-blind-spots.sh"

if [[ -f "$MATRIX" ]]; then
  # verify-work scopes zero-tag checks to the active story, not future siblings.
  # Guard the grep pipeline so a missing active_story becomes a warning.
  ACTIVE_STORY="$(grep '^active_story:' "$STATE" 2>/dev/null | awk '{print $2}' || true)"
  if [[ -z "$ACTIVE_STORY" ]]; then
    classify WARNING "$STATE has no active_story set — zero-tag check skipped, not a pass"
  else
    STORY_EXISTS="$(jq --arg s "$ACTIVE_STORY" '[.stories[]? | select(.id == $s)] | length' "$MATRIX" 2>/dev/null || echo 0)"
    if [[ "$STORY_EXISTS" -eq 0 ]]; then
      classify WARNING "active_story $ACTIVE_STORY not found in $MATRIX — zero-tag check skipped, not a pass"
    else
      UNDONE="$(jq --arg s "$ACTIVE_STORY" '[.stories[]? | select(.id == $s and .status != "done" and ((.links // []) | map(select(.method == "explicit_tag")) | length) == 0)] | length' "$MATRIX" 2>/dev/null || echo 0)"
      (( UNDONE > 0 )) && classify BLOCKER "active story $ACTIVE_STORY has zero explicit story-tag links"
    fi
  fi
  COVERAGE="$(jq -r '.summary.coverage_percent // .coverage_percent // empty' "$MATRIX" 2>/dev/null)"
  if [[ -n "$COVERAGE" && "$COVERAGE" != "null" ]]; then
    awk -v c="$COVERAGE" 'BEGIN{if(c+0 < 60) exit 1}' || classify WARNING "Trace coverage ${COVERAGE}% below 60% target"
    awk -v c="$COVERAGE" 'BEGIN{if(c+0 >= 80) exit 0; exit 1}' && classify FILLED "Trace coverage ${COVERAGE}% meets 80% PASS bar"
  fi
fi

if [[ -f "$BLIND_SPOTS" ]]; then
  HIGH="$(jq '[.findings[]? | select(.severity == "HIGH")] | length' "$BLIND_SPOTS" 2>/dev/null || echo 0)"
  (( HIGH > 0 )) && classify BLOCKER "$HIGH HIGH-severity blind-spot finding(s) remain open in $BLIND_SPOTS"
fi

# Verify evidence for done stories.
VERIFICATIONS="$SPECS_ROOT/verifications"
if [[ -d "$VERIFICATIONS" ]]; then
  VC="$(find "$VERIFICATIONS" -maxdepth 1 -name '*-verify.yaml' 2>/dev/null | wc -l | tr -d ' ')"
  (( VC == 0 )) && classify WARNING "No $VERIFICATIONS/*-verify.yaml evidence bundles"
  (( VC > 0 )) && classify FILLED "$VC verification evidence bundle(s) on disk"
else
  classify WARNING "Verifications directory missing: $VERIFICATIONS"
fi

echo "---"
echo "completeness-critic: BLOCKER=$BLOCKERS WARNING=$WARNINGS FILLED=$FILLED"
if (( BLOCKERS > 0 )); then
  echo "MERGE GATE ABORT: BLOCKER findings must be resolved" >&2
  exit 1
fi
