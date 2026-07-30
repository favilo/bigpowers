#!/usr/bin/env bash
# story: e81s01 e81s04
# Consumer-project integration coverage for configurable specs roots.
set -euo pipefail

BIGPOWERS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJECT="$TMP/consumer"
mkdir -p "$PROJECT/.bigpowers" "$PROJECT/.specs/epics/e99-test" "$PROJECT/.specs/verifications"
cat > "$PROJECT/.bigpowers/config.yaml" <<'YAML'
specs_dir: .specs
YAML
cat > "$PROJECT/.specs/release-plan.yaml" <<'YAML'
release:
  version: "1.0.0"
epics:
  - id: e99
    title: "Consumer test"
    wsjf: 1
    bcps: 1
    capsule_dir: epics/e99-test
YAML
cat > "$PROJECT/.specs/execution-status.yaml" <<'YAML'
development_status:
  e99s01: "backlog"
stories:
  e99s01:
    status: "backlog"
YAML
cat > "$PROJECT/.specs/state.yaml" <<'YAML'
active_flow: null
active_story: e99s01
bigpowers_version: "1.0.0"
YAML
cat > "$PROJECT/.specs/epics/e99-test/epic.yaml" <<'YAML'
stories:
  - id: e99s01
    title: "Consumer test story"
    status: backlog
YAML
cat > "$PROJECT/app.sh" <<'SH'
#!/usr/bin/env bash
# story: e99s01
SH
chmod +x "$PROJECT/app.sh"

run_gate() {
  local script="$1"
  shift
  (cd /tmp && BIGPOWERS_PROJECT_ROOT="$PROJECT" bash "$BIGPOWERS_ROOT/scripts/$script" "$@")
}

run_gate trace-stories.sh --json
[[ -f "$PROJECT/.specs/traceability-matrix.json" ]]
[[ ! -f "$BIGPOWERS_ROOT/specs/traceability-matrix.json.consumer-test" ]]
run_gate check-blind-spots.sh
run_gate check-spec-drift.sh
run_gate golden-g12-status-consistency.sh
run_gate run-gate-trace-verify.sh
run_gate run-gate-trace-verify.sh --self-test
[[ -f "$PROJECT/.specs/verifications/fixtures/gate-trace-selftest/traceability-matrix.json" ]]
[[ ! -d "$BIGPOWERS_ROOT/specs/verifications/fixtures/gate-trace-selftest" ]]
set +e
version_output="$(bash "$BIGPOWERS_ROOT/scripts/check-spec-version-gap.sh" --project "$PROJECT" 2>&1)"
version_exit=$?
set -e
[[ "$version_exit" -eq 1 && "$version_output" == *".specs"* ]]
[[ -f "$PROJECT/.specs/blind-spots.json" ]]
[[ -f "$PROJECT/.specs/drift-report.json" ]]

ABSOLUTE_SPECS="$TMP/absolute-specs"
cp -R "$PROJECT/.specs/." "$ABSOLUTE_SPECS" 2>/dev/null || {
  mkdir -p "$ABSOLUTE_SPECS"
  cp -R "$PROJECT/.specs/." "$ABSOLUTE_SPECS"
}
rm -f "$ABSOLUTE_SPECS"/{traceability-matrix.json,blind-spots.json,drift-report.json}
(cd /tmp && BIGPOWERS_PROJECT_ROOT="$PROJECT" BIGPOWERS_SPECS_DIR="$ABSOLUTE_SPECS" \
  bash "$BIGPOWERS_ROOT/scripts/trace-stories.sh" --json)
[[ -f "$ABSOLUTE_SPECS/traceability-matrix.json" ]]
(cd /tmp && BIGPOWERS_PROJECT_ROOT="$PROJECT" BIGPOWERS_SPECS_DIR="$ABSOLUTE_SPECS" \
  bash "$BIGPOWERS_ROOT/scripts/golden-g12-status-consistency.sh" --self-test)
[[ -f "$ABSOLUTE_SPECS/verifications/fixtures/gate-trace-selftest/traceability-matrix.json" || -d "$ABSOLUTE_SPECS/epics" ]]

if [[ -f "$PROJECT/.specs/traceability-matrix.json" && -f "$ABSOLUTE_SPECS/traceability-matrix.json" ]]; then
  echo "test-consumer-project-gates: PASS"
else
  echo "test-consumer-project-gates: FAIL" >&2
  exit 1
fi
