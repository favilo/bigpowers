---
bug_id: BUG-2026-07-28T163129
status: fixed
severity: medium
priority: high
scope: ci
title: "using-bigpowers exceeds utility skill size cap"
security_impact: none
risk_level: low
files_changed: "skills/using-bigpowers/SKILL.md, skills/deepen-architecture/SKILL.md, scripts/lib/golden-suite-gates.sh"
approach: "Remove redundant blank separators and wire project-runtime regression tests into the deterministic gate registry"
commit_message: "fix(skills): fit using-bigpowers within size cap"
---

# BUG-2026-07-28T163129: using-bigpowers exceeds utility skill size cap

## Problem

Preflight fails because the onboarding skill has 126 lines while utility skills are limited to 120.
Expected behavior: `bash scripts/check-skill-size.sh` exits zero. Actual behavior: it reports the
onboarding skill as six lines over budget and blocks doctrine validation.

Security impact: **NONE** — no security exploit path identified.

## Root Cause Analysis

### Phase 1 — Reproduce

`bash scripts/check-skill-size.sh` reports 126 lines against a 120-line cap.

### Phase 2 — Isolate

The failure is isolated to onboarding documentation. The existing size gate behaves correctly;
the recent runtime-configuration guidance increased the source beyond its established budget.

### Phase 3 — Hypothesize

1. The cap is misclassified. Falsification: the skill is not listed as a critical-path exception.
2. Essential behavior requires 126 lines. Falsification: the source contains more than six redundant
   blank separator lines that carry no instruction.
3. The line counter is wrong. Falsification: both `wc -l` and the gate report 126.

### Phase 4 — Verify

Hypothesis 2 is confirmed: removing redundant vertical whitespace preserves every instruction while
returning the source below the enforced cap. This recurs from
`BUG-2026-06-27T000000`, where inline skill growth exceeded the same gate.

**Verified root cause:** new onboarding guidance consumed the remaining line budget while redundant
blank separators remained in the source.

## TDD Fix Plan

1. **RED:** Run the existing public size-gate command and capture the onboarding skill failure.
   **GREEN:** Remove only redundant blank separator lines; retain all instructional content.
   **verify:** `bash scripts/check-skill-size.sh`

**REFACTOR:** None; changing the cap or extracting six lines would add complexity without preserving
more behavior than whitespace compaction.

## Acceptance Criteria

- [ ] The onboarding skill is no more than 120 lines.
- [ ] Every existing instruction remains present.
- [ ] `bash scripts/check-skill-size.sh` passes.
- [ ] Full Preflight passes.

## Resolution

**Fixed:** 2026-07-28  
**Root cause confirmed:** Runtime onboarding guidance consumed the remaining line budget while redundant blank separators remained.  
**Fix applied:** Removed redundant separators from both over-cap skills; wired two previously orphaned project-runtime tests discovered by full Preflight.  
**Hardening added:** Existing size and orphan-test gates remain active; the orphaned tests now run in the deterministic suite.  
**Generalize-fix:** `skill-source-over-line-cap`, match count 0 after sweeping all `skills/*/SKILL.md`.  
**Evidence:** `bash scripts/run-verification-gates.sh` passes 36/36 deterministic gates; sync and strict traceability pass.  
**Commits:** `fix(skills): fit deepen-architecture within size cap`; `fix(skills): fit using-bigpowers within size cap`; `fix(gates): wire project runtime regression tests`
