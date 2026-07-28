#!/usr/bin/env bash
# story: e81s03
# scenario: SC-e81s03-P0-01
# scenario: SC-e81s03-P0-02
# scenario: SC-e81s03-P0-03
# scenario: SC-e81s03-P1-01
# scenario: SC-e81s03-P1-02
# scenario: SC-e81s03-P0-04
# scenario: SC-e81s03-P0-05
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

overridden_snapshot="$(BIGPOWERS_VCS=git bp_vcs_snapshot "$REAL_COLOCATED")"
if [[ "$overridden_snapshot" != *"kind=git"* ]]; then
  echo "FAIL explicit Git override — requested adapter was not selected" >&2
  exit 1
fi

if invalid_output="$(BIGPOWERS_VCS=jj bp_vcs_snapshot "$GIT_PROJECT" 2>&1)"; then
  echo "FAIL explicit Jujutsu override — non-Jujutsu repository unexpectedly passed" >&2
  exit 1
elif [[ "$invalid_output" != *"initialize Jujutsu"* ]]; then
  echo "FAIL explicit Jujutsu override — remediation hint missing" >&2
  exit 1
fi

echo "PASS explicit VCS overrides validate the selected repository"

jj_survey="$(cd "$REAL_COLOCATED" && bash "$ROOT/scripts/project-survey.sh")"
git_survey="$(cd "$GIT_PROJECT" && bash "$ROOT/scripts/project-survey.sh")"
for expected in "VCS: jj" "Change ID:" "Parent Bookmark:"; do
  if [[ "$jj_survey" != *"$expected"* ]]; then
    echo "FAIL Jujutsu survey — expected '$expected'" >&2
    exit 1
  fi
done
for expected in "VCS: git" "Branch: main" "VCS Status:" "Recent Logs:"; do
  if [[ "$git_survey" != *"$expected"* ]]; then
    echo "FAIL Git survey — expected '$expected'" >&2
    exit 1
  fi
done
if [[ "$jj_survey" == *"detached HEAD"* ]]; then
  echo "FAIL Jujutsu survey — detached Git state leaked" >&2
  exit 1
fi

echo "PASS project survey renders native VCS state"

GUIDANCE_FILES=(
  "$ROOT/skills/survey-context/SKILL.md"
  "$ROOT/skills/kickoff-branch/SKILL.md"
  "$ROOT/skills/session-state/SKILL.md"
  "$ROOT/skills/commit-message/SKILL.md"
  "$ROOT/skills/release-branch/SKILL.md"
)
for guidance_file in "${GUIDANCE_FILES[@]}"; do
  if ! grep -q 'vcs.kind' "$guidance_file" || ! grep -q 'jj ' "$guidance_file"; then
    echo "FAIL Jujutsu guidance — missing conditional procedure in $guidance_file" >&2
    exit 1
  fi
done
if grep -hE 'jj (new|describe|commit|squash)' "${GUIDANCE_FILES[@]}" \
  | grep -v -- '-m ' >/dev/null; then
  echo "FAIL Jujutsu guidance — mutating command can open an editor" >&2
  exit 1
fi

if unsupported_output="$(bp_require_vcs_operation "$REAL_COLOCATED" land-branch 2>&1)"; then
  echo "FAIL unsupported operation — land-branch unexpectedly allowed for Jujutsu" >&2
  exit 1
elif [[ "$unsupported_output" != *"not supported for VCS 'jj'"* ]]; then
  echo "FAIL unsupported operation — actionable VCS failure missing" >&2
  exit 1
fi

echo "PASS Jujutsu guidance is conditional, non-interactive, and fail-closed"
