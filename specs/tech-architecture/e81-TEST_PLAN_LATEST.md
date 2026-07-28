# story: e81s01 e81s02 e81s03
# Test Design: e81 — Configurable Project Runtime

Epic: e81-configurable-project-runtime | Risk owner: plan-tests | Date: 2026-07-28

## 1. Risk Matrix & Scenarios

| Scenario ID | Behavior | Risk | Level | Target |
|-------------|----------|------|-------|--------|
| SC-e81s01-P1-01 | Default runtime configuration resolves `specs` and auto-detects the repository VCS | P1 | Unit | `scripts/test-project-runtime.sh` |
| SC-e81s01-P1-02 | Project configuration is overridden by `BIGPOWERS_SPECS_DIR` and `BIGPOWERS_VCS` | P1 | Unit | `scripts/test-project-runtime.sh` |
| SC-e81s01-P1-03 | Invalid or empty configuration fails with the offending value and remediation | P1 | Unit | `scripts/test-project-runtime.sh` |
| SC-e81s02-P1-01 | A `.specs` fixture stores timing and state changes only below its configured artifact root | P1 | Integration | `scripts/test-configurable-specs-root.sh` |
| SC-e81s02-P1-02 | Survey, validation, migration, dashboard, and MCP state lookup share the configured-root contract | P1 | Integration | `scripts/test-configurable-specs-root.sh` |
| SC-e81s02-P1-03 | Default fixtures remain backward-compatible with the `specs/` root | P1 | Integration | `scripts/test-configurable-specs-root.sh` |
| SC-e81s02-P1-04 | Generated Pi guidance tells agents to substitute the configured artifact root | P1 | Integration | `scripts/sync-skills.sh --distribute-only` |
| SC-e81s03-P0-01 | Auto discovery chooses Jujutsu before Git in a colocated `.jj` + `.git` fixture | P0 | Unit | `scripts/test-project-vcs.sh` |
| SC-e81s03-P0-02 | Jujutsu state reports a stable change ID and parent bookmark without detached-HEAD wording | P0 | Integration | `scripts/test-project-vcs.sh` |
| SC-e81s03-P0-03 | Git-only and plain Git fixtures preserve existing branch, status, and log output | P0 | Integration | `scripts/test-project-vcs.sh` |
| SC-e81s03-P0-04 | Jujutsu lifecycle guidance uses `jj status`, `jj log`, stable change IDs, and non-interactive mutation options | P0 | Integration | `scripts/test-project-vcs.sh` |
| SC-e81s03-P0-05 | Unsupported Git-only operations fail explicitly when Jujutsu mode is selected | P0 | Integration | `scripts/test-project-vcs.sh` |
| SC-e81s03-P1-01 | Explicit `git`, `jj`, and `auto` overrides select the requested adapter or return an actionable executable/repository error | P1 | Unit | `scripts/test-project-vcs.sh` |
| SC-e81s03-P1-02 | Project survey renders VCS-neutral labels and recent history for both adapters | P1 | Integration | `scripts/test-project-vcs.sh` |

**Traceability:** Test files must include `# scenario: SC-e81sYY-Px-NN` beside the existing
`# story: e81sYY` tag. The P0 e81s03 scenarios are release-blocking.

## 2. Test Level Strategy

- **Unit:** dependency-free resolver and adapter functions against temporary directory fixtures.
- **Integration:** invoke public scripts in temporary Git, Jujutsu, colocated, configured-root, and no-VCS repositories.
- **Generated-artifact integration:** distribute canonical skills, then inspect generated Pi guidance rather than editing generated files.
- **Manual UAT:** review one real colocated working copy after automated fixtures pass.
- **No network or browser E2E:** the behaviors are local filesystem and VCS contracts.

Default to the lowest level that proves public behavior. Tests must not assert private helper state.

## 3. Fixture Architecture & Isolation

Create every fixture below `mktemp -d` and remove it with an `EXIT` trap:

| Fixture | Shape | Purpose |
|---------|-------|---------|
| `no-vcs` | project directory only | Explicit unsupported/no-repository behavior |
| `git-only` | initialized Git repository with one commit and branch | Backward compatibility |
| `jj-only` | initialized Jujutsu repository where supported by installed `jj` | Native Jujutsu identity |
| `colocated` | Jujutsu repository backed by Git | Detection precedence and detached-HEAD regression |
| `configured-git` | `.bigpowers/config.yaml` with `vcs: git` | Explicit override |
| `configured-jj` | `.bigpowers/config.yaml` with `vcs: jj` | Explicit override |
| `private-root` | `.bigpowers/config.yaml` with `specs_dir: .specs` | Artifact-root isolation |

- Use local VCS identity configuration inside fixtures; never depend on the user's global identity.
- Seed deterministic commit descriptions so status/log assertions do not depend on timestamps.
- Skip no required P0 scenario. If `jj` is unavailable, fail with an installation hint rather than reporting a false pass.
- Invoke scripts through their public CLI or sourced public adapter functions; do not inspect `.git` or `.jj` internals after setup.
- Do not mutate the contributor repository from fixture tests.

## 4. P0 Regression Oracles

| Scenario | Required observable result |
|----------|----------------------------|
| SC-e81s03-P0-01 | Adapter kind is exactly `jj` for the colocated fixture |
| SC-e81s03-P0-02 | Output contains a Jujutsu change ID and bookmark field; output excludes `detached HEAD` |
| SC-e81s03-P0-03 | Git output retains branch name, short status, and recent log semantics |
| SC-e81s03-P0-04 | Canonical Jujutsu guidance contains only non-interactive mutation examples with `-m` or equivalent explicit options |
| SC-e81s03-P0-05 | Unsupported operation exits non-zero and names the operation, selected VCS, and remediation |

## 5. NFR Verification

| NFR | Requirement | Verification |
|-----|-------------|--------------|
| Compatibility | Bash 3.2 syntax; existing Git behavior unchanged | `bash scripts/test-project-runtime.sh && bash scripts/test-project-vcs.sh` |
| Reliability | Adapter never infers Jujutsu state from colocated Git detached HEAD | `bash scripts/test-project-vcs.sh` |
| Safety | Agent-prescribed Jujutsu mutations are non-interactive; unsupported Git-only paths fail closed | `bash scripts/test-project-vcs.sh` plus skill-source review |
| Isolation | Fixture tests leave the contributor working copy unchanged except generated output explicitly under test | `jj diff --summary` before/after manual verification |
| Operability | Missing `git`/`jj`, invalid override, and unsupported operation errors include remediation | `bash scripts/test-project-vcs.sh` |

## 6. Hard Gates

| Gate | Command | Block? |
|------|---------|--------|
| Runtime resolver | `bash scripts/test-project-runtime.sh` | Yes |
| Configurable root | `bash scripts/test-configurable-specs-root.sh` | Yes |
| VCS adapter | `bash scripts/test-project-vcs.sh` | Yes |
| Skill distribution | `bash scripts/sync-skills.sh --distribute-only && bash scripts/test-project-vcs.sh` | Yes |
| Full Preflight | `npm run compliance && bash scripts/run-verification-gates.sh && bash scripts/sync-skills.sh && bash scripts/trace-stories.sh --strict` | Yes |

## 7. Manual UAT

1. Run `bash scripts/test-project-vcs.sh`; confirm all Git, Jujutsu, and colocated fixtures pass.
2. Run `BIGPOWERS_VCS=jj bash scripts/project-survey.sh` in this colocated repository.
3. Confirm survey output names Jujutsu, shows a stable change ID and parent bookmark, and contains no detached-HEAD warning.
4. Inspect generated survey, kickoff, session, commit, and release guidance; confirm every Jujutsu mutation is non-interactive.
5. Select one documented Git-only operation in Jujutsu mode and confirm it fails with an actionable message.

## 8. Out of Scope

- Non-Git-backed Jujutsu remotes.
- Reimplementation of contributor Git/GitHub release automation.
- Performance benchmarking beyond ensuring local commands complete without hangs.
- Internal `.jj` storage-format assertions.

## 9. Consumer Wiring

| Consumer | Obligation |
|----------|------------|
| `plan-work` | Add these scenario IDs to e81 story acceptance criteria and task verification |
| `develop-tdd` | Implement e81s03 P0 scenarios before P1 scenarios |
| `verify-work` | Run every hard gate and the manual UAT above |
| `gate-trace` | Require `SC-e81s03-P0-*` references in `scripts/test-project-vcs.sh` |

## References

- `specs/epics/e81-configurable-project-runtime/epic.yaml`
- `specs/epics/e81-configurable-project-runtime/e81s03-jujutsu-lifecycle.md`
- `specs/epics/e81-configurable-project-runtime/e81s03-tasks.yaml`
- `specs/tech-architecture/tech-stack.md`
