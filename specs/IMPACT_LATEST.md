## Target
Consumer-project path resolution for project-facing validation gates and `survey-context` guidance.

## Dependents
- `scripts/lib/project-runtime.sh`: shared resolver used by runtime-aware scripts.
- `scripts/trace-stories.sh` + `scripts/lib/trace-stories.py`: traceability inputs and generated artifacts.
- `scripts/check-blind-spots.sh` + `scripts/lib/blind-spots.py`: blind-spot inputs and report.
- `scripts/check-spec-drift.sh`: trace matrix reader and drift report writer.
- `scripts/check-spec-version-gap.sh`: consumer project state/version reader.
- `scripts/golden-g12-status-consistency.sh`: SoT consistency checker and self-test fixture.
- `scripts/run-gate-trace-verify.sh` + `scripts/lib/completeness-critic.sh`: gate chain orchestration and artifact checks.
- `skills/survey-context/SKILL.md`: agent guidance for locating the project cockpit.

## Contracts
- `BIGPOWERS_PROJECT_ROOT` defaults to the invocation directory.
- `BIGPOWERS_SPECS_DIR` overrides `.bigpowers/config.yaml` `specs_dir`.
- Relative specs directories resolve under the project root; absolute paths remain absolute.
- Bigpowers installation paths remain the source for bundled code, migration registry, fixtures, and skills.
- Consumer inputs and generated artifacts must not be read from or written to the Bigpowers checkout.

## Test Coverage
- Existing: `scripts/test-project-runtime.sh`, `scripts/test-configurable-specs-root.sh`, `scripts/test-trace-strict.sh`.
- Gap: no end-to-end fixture exercises the complete traceability → blind-spots → drift → gate-trace chain against a configured consumer specs directory.
- Gap: `survey-context` still documents literal `specs/` paths and has no consumer-layout validation.

## Risk: High
These scripts form shared validation gates and write generated artifacts; a path-resolution regression can silently validate the wrong project or mutate the Bigpowers checkout.

## Recommended action
Add consumer-layout integration coverage first, migrate each affected gate to the shared runtime resolver, update the Python engines and completeness helper, then regenerate skill artifacts and run the self-run regression suite.
