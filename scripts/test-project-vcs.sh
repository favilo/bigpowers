#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/project-vcs.sh"

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

COLOCATED_PROJECT="$TMPDIR_ROOT/colocated"
mkdir -p "$COLOCATED_PROJECT/.git" "$COLOCATED_PROJECT/.jj"

snapshot="$(bp_vcs_snapshot "$COLOCATED_PROJECT")"
kind="$(printf '%s\n' "$snapshot" | sed -n 's/^kind=//p')"

if [[ "$kind" != "jj" ]]; then
  echo "FAIL auto discovery — expected 'jj', got '$kind'" >&2
  exit 1
fi

echo "PASS auto discovery prefers Jujutsu"
