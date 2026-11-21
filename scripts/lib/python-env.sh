#!/usr/bin/env bash
# story: BUG-2026-07-04-python-interpreter-fragility
# Resolve the repository-local uv-managed interpreter (.venv).
# Source this script, then use "$PYTHON" instead of bare python3.
#
# Never falls back to PATH python3. Missing uv or .venv → exit 2 with
# the exact setup command: uv sync --locked

resolve_python() {
  local script_dir repo_root venv_python
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  repo_root="$script_dir"
  venv_python="$repo_root/.venv/bin/python"

  if ! command -v uv >/dev/null 2>&1; then
    echo "python-env: ERROR — uv is required but was not found on PATH" >&2
    echo "  Install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
    echo "  Then from the Bigpowers repo root: uv sync --locked" >&2
    return 2
  fi

  if [[ ! -x "$venv_python" ]]; then
    echo "python-env: ERROR — repository .venv is missing or incomplete" >&2
    echo "  From the Bigpowers repo root run: uv sync --locked" >&2
    return 2
  fi

  if ! "$venv_python" -c "import yaml" 2>/dev/null; then
    echo "python-env: ERROR — $venv_python lacks locked dependencies (PyYAML)" >&2
    echo "  From the Bigpowers repo root run: uv sync --locked" >&2
    return 2
  fi

  PYTHON="$venv_python"
  export PYTHON
  echo "python-env: Using $PYTHON" >&2
  return 0
}

resolve_python
