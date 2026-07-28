#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
# scenario: SC-e81s03-P0-02
# scenario: SC-e81s03-P0-03
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

REAL_COLOCATED="$TMPDIR_ROOT/real-colocated"
jj git init --colocate "$REAL_COLOCATED" >/dev/null
real_snapshot="$(bp_vcs_snapshot "$REAL_COLOCATED")"
change_id="$(printf '%s\n' "$real_snapshot" | sed -n 's/^identity=//p')"

if [[ -z "$change_id" || "$real_snapshot" != *"identity_label=Change ID"* ]]; then
  echo "FAIL Jujutsu identity — snapshot did not report a change ID" >&2
  exit 1
fi
if [[ "$real_snapshot" != *"parent_bookmark="* || "$real_snapshot" == *"detached HEAD"* ]]; then
  echo "FAIL Jujutsu context — parent bookmark missing or detached HEAD leaked" >&2
  exit 1
fi

echo "PASS Jujutsu snapshot reports native identity"

GIT_PROJECT="$TMPDIR_ROOT/git-only"
git init -q -b main "$GIT_PROJECT"
git -C "$GIT_PROJECT" config user.name Fixture
git -C "$GIT_PROJECT" config user.email fixture@example.invalid
printf 'seed\n' > "$GIT_PROJECT/README.md"
git -C "$GIT_PROJECT" add README.md
git -C "$GIT_PROJECT" commit -q -m "seed fixture"
printf 'dirty\n' >> "$GIT_PROJECT/README.md"
git_snapshot="$(bp_vcs_snapshot "$GIT_PROJECT")"

for expected in "kind=git" "branch=main" "README.md" "seed fixture"; do
  if [[ "$git_snapshot" != *"$expected"* ]]; then
    echo "FAIL Git compatibility — expected snapshot containing '$expected'" >&2
    exit 1
  fi
done

echo "PASS Git snapshot preserves branch, status, and logs"
