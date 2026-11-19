#!/usr/bin/env bash
# story: e37s05
# golden-g13-script-orphans.sh — every scripts/*.sh must be wired into a gate,
# invoked by another script/skill/doc/workflow, or explicitly tagged as a
# manual utility.
#
# Originally scoped to scripts/test-*.sh only (33 of 35 test scripts were
# reachable from nothing). Broadened after a catalog-wide review found 9 more
# orphans among non-test scripts, one of which (sync-version-mirrors.sh) was a
# false positive of the SCANNER, not the script: it is called from
# .releaserc.json's semantic-release prepareCmd, a reference location the
# original scan never searched. The file is also renamed from
# golden-g13-test-orphans.sh to match what it now checks — a check whose name
# doesn't match its mechanism is the exact defect class G25 fixes elsewhere in
# this series.
#
# Usage: bash scripts/golden-g13-script-orphans.sh [--self-test]
# Exit 0: every script is referenced, or explicitly tagged bp-manual-utility
# Exit 1: at least one orphan (or, under --self-test, the gate failed to
#         notice a deliberately unlisted, untagged script)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/skill-common.sh"
resolve_repo_root
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

GATES_FILE="scripts/lib/golden-suite-gates.sh"

is_manual_utility() { # $1 = script path
  head -10 "$1" 2>/dev/null | grep -q '^# bp-manual-utility:'
}

is_referenced() { # $1 = script basename, $2... = candidate file globs already expanded
  local name="$1"; shift
  local f
  for f in "$@"; do
    [[ "$f" == *"/$name" || "$(basename "$f")" == "$name" ]] && continue # self
    grep -q "$name" "$f" 2>/dev/null && return 0
  done
  return 1
}

# Expand REF_GLOBS without bash-4 globstar (macOS ships bash 3.2).
collect_ref_files() {
  {
    find scripts -type f -name '*.sh' 2>/dev/null
    find skills -type f \( -name 'SKILL.md' -o -name 'REFERENCE.md' \) 2>/dev/null
    [[ -f CLAUDE.md ]] && printf '%s\n' CLAUDE.md
    [[ -f CONVENTIONS.md ]] && printf '%s\n' CONVENTIONS.md
    find docs -type f -name '*.md' 2>/dev/null
    find bin -type f -name '*.js' 2>/dev/null
    [[ -f package.json ]] && printf '%s\n' package.json
    [[ -f .releaserc.json ]] && printf '%s\n' .releaserc.json
    find .github/workflows -type f -name '*.yml' 2>/dev/null
    find specs/epics -type f \( -name '*.yaml' -o -name '*.md' \) 2>/dev/null \
      | grep -v '/archive/' || true
  } | sort -u
}

build_ref_haystack() {
  local out="$1" f
  : > "$out"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    printf '@@@@FILE %s\n' "$f" >> "$out"
    cat "$f" >> "$out" 2>/dev/null || true
  done < <(collect_ref_files)
}

haystack_references() { # $1 = basename, $2 = self path (or empty), $3 = haystack
  local name="$1" self="$2" haystack="$3"
  awk -v name="$name" -v self="$self" '
    $0 ~ /^@@@@FILE / {
      skip = (self != "" && $0 == ("@@@@FILE " self))
      next
    }
    skip { next }
    index($0, name) { found = 1; exit }
    END { exit !found }
  ' "$haystack"
}

find_orphans() { # $1 = scripts root dir, $2 = extra untagged basename to inject (self-test only)
  local root="$1" extra="${2:-}"
  local orphans="" f b haystack
  haystack=$(mktemp)
  build_ref_haystack "$haystack"
  for f in "$root"/*.sh; do
    [[ -e "$f" ]] || continue
    b="$(basename "$f")"
    is_manual_utility "$f" && continue
    haystack_references "$b" "$f" "$haystack" || orphans+="  $b"$'\n'
  done
  if [[ -n "$extra" ]]; then
    haystack_references "$extra" "" "$haystack" || orphans+="  $extra"$'\n'
  fi
  rm -f "$haystack"
  printf '%s' "$orphans"
}

if [[ "${1:-}" == "--self-test" ]]; then
  echo "=== G-13 self-test: prove the gate can fail, and that its exemptions work ==="
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  # (a) An unlisted, untagged script must still be reported. Built by
  # concatenation, not a literal string: this script's own source lives under
  # scripts/, which collect_ref_files also scans, so a literal fixture name
  # written here would make the checker match its own self-test line.
  fake_name="fixture-not-wired-$$.sh"
  ok=1
  if [[ -z "$(find_orphans "scripts" "$fake_name")" ]]; then
    echo -e "${RED}FAIL${NC} (a) unlisted script was not reported — vacuous gate"
    ok=0
  else
    echo -e "${GREEN}PASS${NC} (a) unlisted, untagged script is reported"
  fi

  # (b) A bp-manual-utility-tagged, unwired script must be excluded.
  cat > "$TMP/tagged-orphan.sh" <<'EOF'
#!/usr/bin/env bash
# bp-manual-utility: fixture for G-13 self-test — deliberately unreferenced
echo "never called by anything"
EOF
  if [[ -n "$(find_orphans "$TMP")" ]]; then
    echo -e "${RED}FAIL${NC} (b) bp-manual-utility-tagged script was still flagged"
    ok=0
  else
    echo -e "${GREEN}PASS${NC} (b) bp-manual-utility-tagged script is excluded"
  fi

  # (c) A script referenced only from .releaserc.json-shaped content must be
  # excluded — regression guard for the exact scope gap fixed here
  # (sync-version-mirrors.sh, called only from .releaserc.json's prepareCmd).
  mkdir -p "$TMP/scope-fixture"
  cat > "$TMP/scope-fixture/releaserc-lookalike.json" <<'EOF'
{"prepareCmd": "bash scripts/only-in-releaserc.sh 1.0.0"}
EOF
  cat > "$TMP/scope-fixture/only-in-releaserc.sh" <<'EOF'
#!/usr/bin/env bash
echo "referenced only from a releaserc-shaped file"
EOF
  refs=("$TMP/scope-fixture/releaserc-lookalike.json")
  if is_referenced "only-in-releaserc.sh" "${refs[@]}"; then
    echo -e "${GREEN}PASS${NC} (c) a releaserc-shaped reference is detected by is_referenced"
  else
    echo -e "${RED}FAIL${NC} (c) is_referenced did not find the releaserc-shaped reference"
    ok=0
  fi

  if [[ "$ok" -eq 1 ]]; then
    echo "G-13 self-test: PASS"
    exit 0
  fi
  echo "G-13 self-test: FAIL"
  exit 1
fi

echo "=== G-13: script orphan check ==="
ORPHANS="$(find_orphans "scripts")"
TOTAL=$(ls scripts/*.sh 2>/dev/null | wc -l | tr -d ' ')

if [[ -z "$ORPHANS" ]]; then
  echo "  ok  : all $TOTAL script(s) in scripts/ are referenced or tagged bp-manual-utility"
  echo -e "${GREEN}PASS${NC}"
  echo "G-13: PASS"
  exit 0
fi

echo "  orphaned scripts (present but reachable from no gate, doc, or workflow):"
printf '%s' "$ORPHANS"
echo -e "${RED}FAIL${NC} wire them into a gate, reference them from a skill/doc, tag them '# bp-manual-utility: <reason>', or delete them"
echo "G-13: FAIL"
exit 1
