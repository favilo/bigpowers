#!/usr/bin/env bash
# story: e80s01 e81s04
# Pre-flight runner for gate-trace skill verify.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/project-runtime.sh"

PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)" || {
  echo "run-gate-trace-verify.sh: project root not found: ${BIGPOWERS_PROJECT_ROOT:-$PWD}" >&2
  exit 1
}
SPECS_ROOT="$(bp_specs_path "$PROJECT_ROOT" "")" || exit 1
TRACE_MATRIX="$(bp_specs_path "$PROJECT_ROOT" traceability-matrix.json)"
BLIND_SPOTS="$(bp_specs_path "$PROJECT_ROOT" blind-spots.json)"

self_test() {
  local tmp="$SPECS_ROOT/verifications/fixtures/gate-trace-selftest"
  mkdir -p "$tmp"
  echo '{"stories":{},"coverage_pct":85,"oracle_stats":{"heuristic_ratio":0.2}}' > "$tmp/traceability-matrix.json"
  echo '{"gaps":[]}' > "$tmp/blind-spots.json"
  test -f "$SCRIPT_DIR/lib/completeness-critic.sh"
  grep -q 'R1' "$SCRIPT_DIR/../skills/gate-trace/SKILL.md"
  grep -q 'completeness-critic' "$SCRIPT_DIR/../skills/gate-trace/SKILL.md"
  echo "run-gate-trace-verify: self-test OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  self_test
  exit 0
fi

[[ -d "$SPECS_ROOT" ]] || {
  echo "FAIL: specs directory not found: $SPECS_ROOT (project: $PROJECT_ROOT)" >&2
  exit 1
}
[[ -f "$TRACE_MATRIX" ]] || BIGPOWERS_PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/trace-stories.sh" --json
[[ -f "$BLIND_SPOTS" ]] || BIGPOWERS_PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/check-blind-spots.sh"

if [[ ! -f "$TRACE_MATRIX" ]]; then
  echo "FAIL: missing $TRACE_MATRIX (project: $PROJECT_ROOT)" >&2
  exit 1
fi
if [[ ! -f "$BLIND_SPOTS" ]]; then
  echo "FAIL: missing $BLIND_SPOTS (project: $PROJECT_ROOT)" >&2
  exit 1
fi

BIGPOWERS_PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/lib/completeness-critic.sh"
echo "run-gate-trace-verify: OK"
