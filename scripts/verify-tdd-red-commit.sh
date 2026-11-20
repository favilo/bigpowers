#!/usr/bin/env bash
# story: e80s01 e80s03
# Mechanical gate: the test-only (RED) change must fail in isolation because the
# behavior is absent, not because dependencies or the verify command never started.
#
# Runs in the caller's project. Do not cd to the Bigpowers install.
#   "$BIGPOWERS_ROOT/scripts/verify-tdd-red-commit.sh"
#   TDD_VERIFY_CMD='npm test' "$BIGPOWERS_ROOT/scripts/verify-tdd-red-commit.sh" --rev <change>
#
# Default RED revision: jj `@-`, or git `HEAD~1`.
# Jujutsu is used when `.jj` is present. Raw git is not invoked in that case.
# The RED change is checked out in a detached jj workspace. Ignored dependency
# directories (node_modules and similar) are symlinked into that workspace only.
set -euo pipefail

PROJECT_ROOT="${BIGPOWERS_PROJECT_ROOT:-$PWD}"
RED_REV="${TDD_RED_REV:-}"
SELF_TEST=""

usage() {
  cat <<'EOF'
Usage: verify-tdd-red-commit.sh [--self-test] [--rev <change>]
  --rev    RED change to check out (default: @- or HEAD~1)
  TDD_VERIFY_CMD   command that must fail behaviorally on that change
                   (default: npm test or cargo test)
Jujutsu uses a detached workspace and Git uses a detached worktree. Ignored
dependency directories from the caller are linked into that checkout only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) SELF_TEST=1; shift ;;
    --rev) RED_REV="${2:?--rev needs a change id}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

is_jj() { [[ -d "$PROJECT_ROOT/.jj" ]]; }
is_git() { git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; }

is_setup_output() {
  printf '%s\n' "$1" | grep -E -q \
    'Cannot find module|Cannot find package|ERR_MODULE_NOT_FOUND|MODULE_NOT_FOUND|npm ERR!|SyntaxError|error TS[0-9]+|ELIFECYCLE|Could not resolve|ERR_PACKAGE_PATH_NOT_EXPORTED'
}

is_assertion_output() {
  printf '%s\n' "$1" | grep -E -q 'AssertionError|# fail [0-9]|not ok |Test failed|failing tests'
}

# Install trees that are ignored and therefore absent from a fresh workspace.
DEP_DIRS="node_modules .venv venv vendor bower_components"

link_deps() {
  local dest="$1" name
  for name in $DEP_DIRS; do
    if [[ -e "$PROJECT_ROOT/$name" && ! -e "$dest/$name" && ! -L "$dest/$name" ]]; then
      ln -s "$PROJECT_ROOT/$name" "$dest/$name"
    fi
  done
}

unlink_deps() {
  local dest="$1" name
  for name in $DEP_DIRS; do
    if [[ -L "$dest/$name" ]]; then
      rm -f "$dest/$name"
    fi
  done
}

run_isolated() {
  local dir="$1" label="$2" output rc
  link_deps "$dir"
  set +e
  output=$(cd "$dir" && bash -c "$VERIFY_CMD" 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: test-only change $label passed in isolation — RED gate violated" >&2
    return 1
  fi
  if [[ "$rc" -eq 126 || "$rc" -eq 127 ]]; then
    echo "FAIL: $label did not fail behaviorally (exit $rc — command did not run)" >&2
    printf '%s\n' "$output" | tail -n 20 >&2
    return 1
  fi
  if is_setup_output "$output" && ! is_assertion_output "$output"; then
    echo "FAIL: $label failed during dependency setup, not a behavioral RED (exit $rc)" >&2
    printf '%s\n' "$output" | tail -n 20 >&2
    return 1
  fi
  echo "PASS: test-only change $label fails in isolation (exit $rc)"
}

resolve_verify_cmd() {
  VERIFY_CMD="${TDD_VERIFY_CMD:-}"
  if [[ -n "$VERIFY_CMD" ]]; then
    return 0
  fi
  if [[ -f "$PROJECT_ROOT/package.json" ]] && grep -q '"test"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    VERIFY_CMD="npm test --if-present"
  elif [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
    VERIFY_CMD="cargo test"
  else
    echo "SKIP: set TDD_VERIFY_CMD for this repo"
    exit 0
  fi
}

check_jj() {
  local rev="${RED_REV:-@-}" count rc work name
  if ! command -v jj >/dev/null 2>&1; then
    echo "ERROR: .jj present but jj is not on PATH" >&2
    exit 1
  fi
  count=$(jj --no-pager -R "$PROJECT_ROOT" log -r "::@" --no-graph -T '"x\n"' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${count:-0}" -lt 2 && -z "$RED_REV" ]]; then
    echo "SKIP: need at least 2 changes (test-only RED then fix GREEN)"
    exit 0
  fi
  if ! jj --no-pager -R "$PROJECT_ROOT" log -r "$rev" --no-graph -T 'commit_id' >/dev/null 2>&1; then
    echo "ERROR: cannot resolve RED revision: $rev" >&2
    exit 1
  fi
  work=$(mktemp -d "${TMPDIR:-/tmp}/tdd-red-jj.XXXXXX")
  name="tdd-red-$$-$(basename "$work")"
  # Detached workspace whose parent is the RED change. Does not edit the caller.
  jj --no-pager -R "$PROJECT_ROOT" workspace add --name "$name" -r "$rev" "$work" >/dev/null 2>&1
  rc=0
  run_isolated "$work" "$rev" || rc=$?
  unlink_deps "$work"
  jj --no-pager -R "$PROJECT_ROOT" workspace forget "$name" >/dev/null 2>&1 || true
  rm -rf "$work"
  return "$rc"
}

check_git() {
  local rev="${RED_REV:-HEAD~1}" count rc work
  count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo 0)
  if [[ "$count" -lt 2 && -z "$RED_REV" ]]; then
    echo "SKIP: need at least 2 commits (test-only RED then fix GREEN)"
    exit 0
  fi
  rev=$(git -C "$PROJECT_ROOT" rev-parse "$rev")
  work=$(mktemp -d "${TMPDIR:-/tmp}/tdd-red-git.XXXXXX")
  git -C "$PROJECT_ROOT" worktree add -q --detach "$work" "$rev"
  rc=0
  run_isolated "$work" "$rev" || rc=$?
  unlink_deps "$work"
  git -C "$PROJECT_ROOT" worktree remove -f "$work" 2>/dev/null || rm -rf "$work"
  return "$rc"
}

seed_red_tree() {
  local root="$1"
  mkdir -p "$root/test"
  echo 'node_modules' > "$root/.gitignore"
  cat > "$root/package.json" <<'JSON'
{"name":"tdd-fixture","scripts":{"test":"node test/run.js"}}
JSON
  cat > "$root/test/run.js" <<'JS'
const fs = require('fs');
process.exit(fs.existsSync('src/impl.js') ? 0 : 1);
JS
}

self_test_git() {
  local tmp script red
  tmp=$(mktemp -d)
  script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "tdd-verify@bigpowers.local"
  git -C "$tmp" config user.name "tdd-verify"
  seed_red_tree "$tmp"
  git -C "$tmp" add .
  git -C "$tmp" commit -q -m "test(scope): red"
  mkdir -p "$tmp/src"
  echo 'module.exports = {};' > "$tmp/src/impl.js"
  git -C "$tmp" add src/impl.js
  git -C "$tmp" commit -q -m "fix(scope): green"
  red=$(git -C "$tmp" rev-parse HEAD~1)
  if ! BIGPOWERS_PROJECT_ROOT="$tmp" TDD_VERIFY_CMD='node test/run.js' bash "$script" --rev "$red"; then
    echo "FAIL: git self-test — RED commit should fail in isolation" >&2
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  echo "PASS: git RED isolation"
}

expect_fail_with() {
  local needle="$1"
  shift
  local out rc
  set +e
  out=$("$@" 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]] || ! printf '%s\n' "$out" | grep -q "$needle"; then
    echo "FAIL: expected non-zero and '$needle'" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
}

self_test_jj() {
  local tmp script red before after sentinel out
  if ! command -v jj >/dev/null 2>&1; then
    echo "SKIP: jj self-test — jj not on PATH"
    return 0
  fi
  tmp=$(mktemp -d)
  script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  jj --no-pager git init --colocate "$tmp" >/dev/null
  seed_red_tree "$tmp"
  jj --no-pager -R "$tmp" commit -m "test(scope): red" >/dev/null
  red=$(jj --no-pager -R "$tmp" log -r @- --no-graph -T 'change_id.short()')
  mkdir -p "$tmp/src"
  echo 'module.exports = {};' > "$tmp/src/impl.js"
  before=$(jj --no-pager -R "$tmp" log -r @ --no-graph -T 'change_id')
  if ! BIGPOWERS_PROJECT_ROOT="$tmp" TDD_VERIFY_CMD='node test/run.js' bash "$script"; then
    echo "FAIL: jj self-test — default @- should be the RED change" >&2
    rm -rf "$tmp"
    return 1
  fi
  after=$(jj --no-pager -R "$tmp" log -r @ --no-graph -T 'change_id')
  if [[ "$before" != "$after" || ! -f "$tmp/src/impl.js" ]]; then
    echo "FAIL: jj self-test — caller working copy was disturbed" >&2
    rm -rf "$tmp"
    return 1
  fi
  if ! BIGPOWERS_PROJECT_ROOT="$tmp" TDD_VERIFY_CMD='node test/run.js' bash "$script" --rev "$red"; then
    echo "FAIL: jj self-test — --rev RED change should fail behaviorally" >&2
    rm -rf "$tmp"
    return 1
  fi
  jj --no-pager -R "$tmp" commit -m "fix(scope): green" >/dev/null
  if BIGPOWERS_PROJECT_ROOT="$tmp" TDD_VERIFY_CMD='node test/run.js' bash "$script" --rev @-; then
    echo "FAIL: jj self-test — GREEN change must not satisfy the RED gate" >&2
    rm -rf "$tmp"
    return 1
  fi

  # Missing dependency: no caller node_modules, require() cannot resolve.
  if ! expect_fail_with "dependency setup" \
    env BIGPOWERS_PROJECT_ROOT="$tmp" \
    TDD_VERIFY_CMD="node -e \"require('missing-pkg')\"" \
    bash "$script" --rev "$red"; then
    rm -rf "$tmp"
    return 1
  fi

  # Caller install is linked into the isolated workspace and left untouched.
  mkdir -p "$tmp/node_modules/some-dep"
  echo 'module.exports = 1;' > "$tmp/node_modules/some-dep/index.js"
  sentinel="$tmp/node_modules/.tdd-sentinel"
  echo keep > "$sentinel"
  if ! BIGPOWERS_PROJECT_ROOT="$tmp" \
    TDD_VERIFY_CMD="node -e \"require('some-dep'); process.exit(1)\"" \
    bash "$script" --rev "$red"; then
    echo "FAIL: jj self-test — linked deps should allow a behavioral RED" >&2
    rm -rf "$tmp"
    return 1
  fi
  if [[ ! -f "$sentinel" || -L "$tmp/node_modules" ]]; then
    echo "FAIL: jj self-test — caller node_modules was mutated" >&2
    rm -rf "$tmp"
    return 1
  fi

  # Passing test is not a RED failure.
  if ! expect_fail_with "passed in isolation" \
    env BIGPOWERS_PROJECT_ROOT="$tmp" \
    TDD_VERIFY_CMD="node -e \"require('some-dep')\"" \
    bash "$script" --rev "$red"; then
    rm -rf "$tmp"
    return 1
  fi

  # Import/syntax errors are setup failures, even when deps were linked.
  if ! expect_fail_with "dependency setup" \
    env BIGPOWERS_PROJECT_ROOT="$tmp" \
    TDD_VERIFY_CMD='node -e "function {"' \
    bash "$script" --rev "$red"; then
    rm -rf "$tmp"
    return 1
  fi
  if ! expect_fail_with "dependency setup" \
    env BIGPOWERS_PROJECT_ROOT="$tmp" \
    TDD_VERIFY_CMD="node -e \"require('not-installed-either')\"" \
    bash "$script" --rev "$red"; then
    rm -rf "$tmp"
    return 1
  fi

  rm -rf "$tmp"
  echo "PASS: jj RED isolation"
}

self_test() {
  self_test_git
  self_test_jj
  echo "verify-tdd-red-commit: self-test OK"
}

if [[ "$SELF_TEST" == 1 ]]; then
  self_test
  exit $?
fi

resolve_verify_cmd

if is_jj; then
  check_jj
elif is_git; then
  check_git
else
  echo "ERROR: not a jj or git repository: $PROJECT_ROOT" >&2
  exit 1
fi
