#!/usr/bin/env bash
# story: e38s04
# check-blind-spots.sh — TEA-inspired heuristic blind-spot detector.
# Thin bash wrapper — the detection engine lives in scripts/lib/blind-spots.py.
# Reads execution-status.yaml + traceability-matrix.json, runs 7 structural
# quality checks, and emits specs/blind-spots.json.
# Also detects SC- scenario gaps (sc-gap).
#
# Checks: verify-gap, test-gap, epic-orphan, stale-tag, double-tag, bootstrap-testless, sc-gap.
# Severities: HIGH / MEDIUM / LOW. Exit 1 on HIGH findings.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/python-env.sh"
source "$SCRIPT_DIR/lib/project-runtime.sh"
source "$SCRIPT_DIR/lib/skill-common.sh"
resolve_repo_root

PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)" || {
  echo "check-blind-spots.sh: project root not found: ${BIGPOWERS_PROJECT_ROOT:-$PWD}" >&2
  exit 1
}
SPECS_ROOT="$(bp_specs_path "$PROJECT_ROOT" "")" || exit 1
BLIND_SPOTS_JSON="$(bp_specs_path "$PROJECT_ROOT" blind-spots.json)"
EXEC_STATUS="$(bp_specs_path "$PROJECT_ROOT" execution-status.yaml)"
MATRIX_JSON="$(bp_specs_path "$PROJECT_ROOT" traceability-matrix.json)"
VERIFICATIONS_DIR="$(bp_specs_path "$PROJECT_ROOT" verifications)"
EPICS_DIR="$(bp_specs_path "$PROJECT_ROOT" epics)"

if [[ ! -d "$SPECS_ROOT" ]]; then
  echo "check-blind-spots.sh: specs directory not found: $SPECS_ROOT (project: $PROJECT_ROOT)" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      cat <<'USAGE'
Usage: check-blind-spots.sh [flags]

Run 7 heuristic blind-spot checks on the codebase.

Flags:
  --help   Print this message and exit.

Checks: verify-gap, test-gap, epic-orphan, stale-tag, double-tag, bootstrap-testless, sc-gap.
Output: specs/blind-spots.json
Exit: 0 = no HIGH findings, 1 = HIGH findings or input files missing.
USAGE
      exit 0
      ;;
    *)
      echo "check-blind-spots.sh: unknown flag: $1" >&2
      echo "Try --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$EXEC_STATUS" ]]; then
  echo "check-blind-spots.sh: execution-status.yaml: not found at $EXEC_STATUS" >&2
  exit 1
fi
if [[ ! -f "$MATRIX_JSON" ]]; then
  echo "check-blind-spots.sh: traceability matrix not found at $MATRIX_JSON; run trace-stories.sh first" >&2
  exit 1
fi

exec "$PYTHON" "$SCRIPT_DIR/lib/blind-spots.py" \
  "$PROJECT_ROOT" "$SPECS_ROOT" "$BLIND_SPOTS_JSON" "$EXEC_STATUS" "$MATRIX_JSON" "$VERIFICATIONS_DIR" "$EPICS_DIR"
