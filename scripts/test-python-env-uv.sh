#!/usr/bin/env bash
# story: BUG-2026-07-04-python-interpreter-fragility
# test-python-env-uv.sh — repo-local uv .venv must be the only Python resolver.
#
# Asserts:
#   1. Missing uv → exit 2 with clear error.
#   2. Missing .venv → exit 2 telling the user to run `uv sync --locked`.
#   3. With a synced .venv, PATH python without PyYAML still resolves to
#      .venv/bin/python and `import yaml` succeeds (no host fallback warning).
#
# Usage: bash scripts/test-python-env-uv.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TA_PASS=0
TA_FAIL=0
TA_TMPDIR=""
source "$REPO_ROOT/scripts/lib/test-assertions.sh"
trap ta_cleanup EXIT

TA_TMPDIR="$(mktemp -d)"

# PyYAML-free host interpreter first on PATH (stock macOS / CI image shape).
if ! python3 -m venv "$TA_TMPDIR/host-python" >/dev/null 2>&1; then
  echo "test-python-env-uv: SKIP — cannot create host venv"
  exit 0
fi
HOST_PY="$TA_TMPDIR/host-python/bin/python"
if "$HOST_PY" -c "import yaml" >/dev/null 2>&1; then
  echo "test-python-env-uv: SKIP — fresh venv unexpectedly has PyYAML"
  exit 0
fi
export PATH="$TA_TMPDIR/host-python/bin:$PATH"

# --- 1. Missing uv ---
mkdir -p "$TA_TMPDIR/no-uv/bin"
set +e
out="$(env PATH="$TA_TMPDIR/no-uv/bin:$TA_TMPDIR/host-python/bin:/usr/bin:/bin" \
  bash -c 'source scripts/lib/python-env.sh' 2>&1)"
rc=$?
set -e
if [[ "$rc" -eq 2 ]] && echo "$out" | grep -qi 'uv'; then
  ta_pass "missing uv exits 2 with uv hint"
else
  ta_fail "missing uv should exit 2 with uv hint (rc=$rc)"
  echo "$out" | sed -n '1,8p'
fi

# --- 2. Missing .venv (uv present, no env) ---
FIXTURE="$TA_TMPDIR/fixture-no-venv"
mkdir -p "$FIXTURE/scripts/lib"
cp "$REPO_ROOT/scripts/lib/python-env.sh" "$FIXTURE/scripts/lib/python-env.sh"
if [[ -f "$REPO_ROOT/pyproject.toml" ]]; then
  cp "$REPO_ROOT/pyproject.toml" "$FIXTURE/pyproject.toml"
fi
if [[ -f "$REPO_ROOT/uv.lock" ]]; then
  cp "$REPO_ROOT/uv.lock" "$FIXTURE/uv.lock"
fi
set +e
out="$(cd "$FIXTURE" && bash -c 'source scripts/lib/python-env.sh' 2>&1)"
rc=$?
set -e
if [[ "$rc" -eq 2 ]] && echo "$out" | grep -q 'uv sync --locked'; then
  ta_pass "missing .venv exits 2 with uv sync --locked"
else
  ta_fail "missing .venv should exit 2 with uv sync --locked (rc=$rc)"
  echo "$out" | sed -n '1,8p'
fi

# --- 3. Synced .venv wins over PyYAML-free PATH python ---
if ! command -v uv >/dev/null 2>&1; then
  ta_fail "uv required for synced-.venv case"
elif [[ ! -f "$REPO_ROOT/pyproject.toml" || ! -f "$REPO_ROOT/uv.lock" ]]; then
  ta_fail "pyproject.toml + uv.lock required for synced-.venv case"
else
  FIXTURE2="$TA_TMPDIR/fixture-synced"
  mkdir -p "$FIXTURE2/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/python-env.sh" "$FIXTURE2/scripts/lib/python-env.sh"
  cp "$REPO_ROOT/pyproject.toml" "$FIXTURE2/pyproject.toml"
  cp "$REPO_ROOT/uv.lock" "$FIXTURE2/uv.lock"
  (cd "$FIXTURE2" && uv sync --locked >/dev/null 2>&1)
  set +e
  out="$(cd "$FIXTURE2" && bash -c 'source scripts/lib/python-env.sh; printf %s "$PYTHON"' 2>&1)"
  rc=$?
  set -e
  py_line="$(echo "$out" | tail -n 1)"
  if [[ "$rc" -ne 0 ]]; then
    ta_fail "synced .venv resolve failed (rc=$rc)"
    echo "$out" | sed -n '1,12p'
  elif [[ "$py_line" != "$FIXTURE2/.venv/bin/python" && "$py_line" != "$FIXTURE2/.venv/bin/python3" ]]; then
    ta_fail "PYTHON must be fixture .venv interpreter, got: $py_line"
  elif echo "$out" | grep -qi 'fallback\|lacks PyYAML\|pip install'; then
    ta_fail "must not warn about host fallback / pip install"
    echo "$out" | sed -n '1,12p'
  elif ! "$py_line" -c 'import yaml' >/dev/null 2>&1; then
    ta_fail "resolved PYTHON cannot import yaml"
  else
    ta_pass "synced .venv used despite PyYAML-free PATH python"
  fi
fi

echo "test-python-env-uv: $TA_PASS passed, $TA_FAIL failed"
[[ "$TA_FAIL" -eq 0 ]] || exit 1
