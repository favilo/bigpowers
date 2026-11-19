#!/usr/bin/env bash
# story: BUG-2026-07-04-python-interpreter-fragility
# test-plan-consistency-uv.sh — plan-consistency-check uses repo-local uv .venv
# even when PATH python3 lacks PyYAML.
#
# Usage: bash scripts/test-plan-consistency-uv.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TA_PASS=0
TA_FAIL=0
TA_TMPDIR=""
source "$REPO_ROOT/scripts/lib/test-assertions.sh"
trap ta_cleanup EXIT

TA_TMPDIR="$(mktemp -d)"

if ! command -v uv >/dev/null 2>&1; then
  echo "test-plan-consistency-uv: SKIP — uv not installed"
  exit 0
fi
if [[ ! -f "$REPO_ROOT/pyproject.toml" || ! -f "$REPO_ROOT/uv.lock" ]]; then
  echo "test-plan-consistency-uv: FAIL — pyproject.toml + uv.lock required"
  exit 1
fi

# PyYAML-free host interpreter first on PATH.
if ! python3 -m venv "$TA_TMPDIR/host-python" >/dev/null 2>&1; then
  echo "test-plan-consistency-uv: SKIP — cannot create host venv"
  exit 0
fi
HOST_PY="$TA_TMPDIR/host-python/bin/python"
if "$HOST_PY" -c "import yaml" >/dev/null 2>&1; then
  echo "test-plan-consistency-uv: SKIP — fresh venv unexpectedly has PyYAML"
  exit 0
fi
export PATH="$TA_TMPDIR/host-python/bin:$PATH"

# Disposable fixture copy with a valid mini capsule + uv project files.
FIXTURE="$TA_TMPDIR/bp-fixture"
mkdir -p "$FIXTURE/scripts/lib" "$FIXTURE/specs/epics/e99-fixture"
cp "$REPO_ROOT/scripts/lib/python-env.sh" "$FIXTURE/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/fail-open-detect.sh" "$FIXTURE/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/plan-consistency-check.sh" "$FIXTURE/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/extract-story-verify.py" "$FIXTURE/scripts/lib/"
cp "$REPO_ROOT/pyproject.toml" "$FIXTURE/"
cp "$REPO_ROOT/uv.lock" "$FIXTURE/"

cat > "$FIXTURE/specs/epics/e99-fixture/epic.yaml" <<'YAML'
id: e99
slug: fixture
title: Fixture Capsule
stories:
  - id: e99s01
    title: Mini story
YAML

cat > "$FIXTURE/specs/epics/e99-fixture/e99s01-mini.md" <<'MD'
# e99s01 Mini story

## Acceptance Criteria
- Fixture passes plan-consistency-check

## Verification Script
1. Run the verify command in tasks.yaml
MD

cat > "$FIXTURE/specs/epics/e99-fixture/e99s01-tasks.yaml" <<'YAML'
story: e99s01
spec: e99s01-mini.md
status: todo
tasks:
  - id: t1
    description: Placeholder
    status: todo
    verify: bash -c 'exit 0'
YAML

(cd "$FIXTURE" && uv sync --locked >/dev/null 2>&1)
set +e
out="$(cd "$FIXTURE" && bash scripts/lib/plan-consistency-check.sh specs/epics/e99-fixture 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  ta_fail "plan-consistency-check should PASS on fixture (rc=$rc)"
  echo "$out" | sed -n '1,40p'
elif echo "$out" | grep -qi 'fallback\|lacks PyYAML\|pip install\|WARN —'; then
  ta_fail "must not emit host-Python fallback / PyYAML warning"
  echo "$out" | sed -n '1,40p'
elif ! echo "$out" | grep -q 'PASS: capsule artifacts consistent'; then
  ta_fail "expected PASS line in output"
  echo "$out" | sed -n '1,40p'
else
  ta_pass "plan-consistency uses uv .venv with PyYAML-free PATH"
fi

# Formerly bare-python3 scripts must source python-env (static check).
for script in \
  scripts/validate-skill-catalog.sh \
  scripts/check-import-boundaries.sh \
  scripts/validate-contracts.sh \
  scripts/validate-tombstones.sh \
  scripts/tombstone-skill.sh \
  scripts/test-tombstone-mechanism.sh
do
  if grep -q 'python-env\.sh' "$REPO_ROOT/$script" \
    && ! grep -E '^[[:space:]]*python3([[:space:]]|$)' "$REPO_ROOT/$script" >/dev/null; then
    ta_pass "$script uses shared resolver (no bare python3)"
  else
    ta_fail "$script still invokes bare python3 or skips python-env.sh"
  fi
done

echo "test-plan-consistency-uv: $TA_PASS passed, $TA_FAIL failed"
[[ "$TA_FAIL" -eq 0 ]] || exit 1
