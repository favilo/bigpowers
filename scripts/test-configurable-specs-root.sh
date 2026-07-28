#!/usr/bin/env bash
# story: e81s02
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

pass() {
  echo "  PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL $1" >&2
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    pass "$name"
  else
    fail "$name — expected output containing '$expected', got '$actual'"
  fi
}

make_configured_project() {
  local name="$1"
  local project="$TMPDIR_ROOT/$name"
  mkdir -p "$project/.bigpowers" "$project/.specs"
  cat > "$project/.bigpowers/config.yaml" <<'YAML'
specs_dir: .specs
vcs: auto
YAML
  printf '%s\n' "$project"
}

TIMING_PROJECT="$(make_configured_project timing)"
cat > "$TIMING_PROJECT/.specs/state.yaml" <<'YAML'
active_flow: null
metrics: {}
YAML
(
  cd "$TIMING_PROJECT"
  bash "$ROOT/scripts/bp-timing.sh" start configurable-root-test
  sleep 1
  bash "$ROOT/scripts/bp-timing.sh" end configurable-root-test
)
TIMING_STATE="$(cat "$TIMING_PROJECT/.specs/state.yaml")"
assert_contains "timing writes configured state" "configurable-root-test:" "$TIMING_STATE"
assert_contains "timing records completed call" "calls: 1" "$TIMING_STATE"

SURVEY_PROJECT="$(make_configured_project survey)"
jj git init --colocate "$SURVEY_PROJECT" >/dev/null
cat > "$SURVEY_PROJECT/.specs/state.yaml" <<'YAML'
active_flow: planning
YAML
cat > "$SURVEY_PROJECT/.specs/release-plan.yaml" <<'YAML'
release:
  version: personal
YAML
SURVEY_OUTPUT="$(cd "$SURVEY_PROJECT" && bash "$ROOT/scripts/project-survey.sh" 2>&1)" || true
assert_contains "survey discovers configured root" "SPECS=true" "$SURVEY_OUTPUT"
assert_contains "survey maps configured active flow" "Phase: Plan" "$SURVEY_OUTPUT"
assert_contains "survey lists configured state" "state.yaml" "$SURVEY_OUTPUT"

VALIDATOR_PROJECT="$(make_configured_project validator)"
cat > "$VALIDATOR_PROJECT/.specs/state.yaml" <<'YAML'
wrong_key: true
YAML
cat > "$VALIDATOR_PROJECT/.specs/release-plan.yaml" <<'YAML'
release:
  version: personal
epics:
  - id: e01
YAML
cat > "$VALIDATOR_PROJECT/.specs/execution-status.yaml" <<'YAML'
development_status: {}
YAML
if (cd "$VALIDATOR_PROJECT" && bash "$ROOT/scripts/validate-specs-yaml.sh" >/tmp/bp-validator.out 2>&1); then
  fail "validator reads configured root — invalid configured state unexpectedly passed"
elif grep -q "$VALIDATOR_PROJECT/.specs/state.yaml" /tmp/bp-validator.out; then
  pass "validator reads configured root"
else
  fail "validator reads configured root — failure did not reference configured state"
fi

MIGRATION_PROJECT="$(make_configured_project migration)"
cat > "$MIGRATION_PROJECT/.specs/state.yaml" <<'YAML'
active_flow: null
bigpowers_version: 2.87.0
YAML
MIGRATION_OUTPUT="$(bash "$ROOT/scripts/migrate-version.sh" --dry-run --force --project "$MIGRATION_PROJECT" 2>&1)" || true
assert_contains "migration resolves configured root" \
  "detected=2.87.0 installed=2.87.0" "$MIGRATION_OUTPUT"

if grep -q "configured artifact root" "$ROOT/skills/using-bigpowers/SKILL.md"; then
  pass "canonical onboarding skill defines artifact-root substitution"
else
  fail "canonical onboarding skill defines artifact-root substitution"
fi

if grep -q "configured artifact root" "$ROOT/.pi/skills/using-bigpowers/SKILL.md"; then
  pass "generated Pi onboarding skill defines artifact-root substitution"
else
  fail "generated Pi onboarding skill defines artifact-root substitution"
fi

echo "---"
echo "test-configurable-specs-root: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
