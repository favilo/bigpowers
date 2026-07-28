#!/usr/bin/env bash
# story: e39s03
# Compare spec-file mtimes against implementing source-file mtimes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/python-env.sh"
source "$SCRIPT_DIR/lib/project-runtime.sh"

PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)" || {
  echo "check-spec-drift.sh: project root not found: ${BIGPOWERS_PROJECT_ROOT:-$PWD}" >&2
  exit 1
}
SPECS_ROOT="$(bp_specs_path "$PROJECT_ROOT" "")" || exit 1
TRACE_MATRIX="$(bp_specs_path "$PROJECT_ROOT" traceability-matrix.json)"
DRIFT_REPORT="$(bp_specs_path "$PROJECT_ROOT" drift-report.json)"

if [ "$#" -eq 1 ] && [ "$1" = "--help" ]; then
  echo "Usage: $(basename "$0") [--help]"
  echo "Compare traceability mtimes; write $DRIFT_REPORT."
  exit 0
fi
if [[ ! -d "$SPECS_ROOT" ]]; then
  echo "[ERROR] Specs directory not found: $SPECS_ROOT (project: $PROJECT_ROOT)" >&2
  exit 1
fi
if [[ ! -f "$TRACE_MATRIX" ]]; then
  echo "[ERROR] Traceability matrix not found: $TRACE_MATRIX" >&2
  echo "[ERROR] Run scripts/trace-stories.sh first" >&2
  exit 1
fi

"$PYTHON" - "$PROJECT_ROOT" "$TRACE_MATRIX" "$DRIFT_REPORT" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

repo_root, trace_matrix, drift_report = sys.argv[1:]
with open(trace_matrix, encoding="utf-8") as stream:
    matrix = json.load(stream)

drift = {
    "meta": {
        "generated_by": "scripts/check-spec-drift.sh",
        "source": trace_matrix,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    },
    "suspect_links": [],
    "broken_links": [],
    "summary": {"suspect": 0, "broken": 0, "ok": 0},
}

stories = matrix.get("stories", [])
assert isinstance(stories, list), "stories must be a list"

for entry in stories:
    story_id = entry.get("id", "")
    spec_path = entry.get("spec_path", "")
    if spec_path and not os.path.isabs(spec_path):
        spec_path = os.path.join(repo_root, spec_path)
    links = entry.get("links", [])
    if not links:
        drift["broken_links"].append({"story_id": story_id, "reason": "no trace links", "severity": "broken"})
        drift["summary"]["broken"] += 1
        continue

    suspect_files = []
    for link in links:
        impl_file = link.get("file")
        if not impl_file:
            continue
        impl_full = impl_file if os.path.isabs(impl_file) else os.path.join(repo_root, impl_file)
        if not os.path.exists(impl_full):
            drift["broken_links"].append({"story_id": story_id, "spec": spec_path, "file": impl_file,
                                           "reason": "implementing file does not exist", "severity": "broken"})
            drift["summary"]["broken"] += 1
            continue
        if spec_path and os.path.exists(spec_path) and os.path.getmtime(impl_full) > os.path.getmtime(spec_path):
            impl_mtime = os.path.getmtime(impl_full)
            spec_mtime = os.path.getmtime(spec_path)
            suspect_files.append({"file": impl_file, "impl_mtime": impl_mtime,
                                  "spec_mtime": spec_mtime,
                                  "age_seconds": impl_mtime - spec_mtime})

    if suspect_files:
        drift["suspect_links"].append({"story_id": story_id, "spec": spec_path, "files": suspect_files})
        drift["summary"]["suspect"] += 1
    else:
        drift["summary"]["ok"] += 1

with open(drift_report, "w", encoding="utf-8") as stream:
    json.dump(drift, stream, indent=2)
print(f'OK: {drift["summary"]["ok"]} clean, {drift["summary"]["suspect"]} suspect, {drift["summary"]["broken"]} broken')
PY
