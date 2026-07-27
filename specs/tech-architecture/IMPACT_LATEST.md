# Impact Assessment: Configurable Project Runtime

## Target

Project-facing scripts and skills that assume `specs/` and Git.

## Dependents

- 78 files under `scripts/`, `bin/`, and `dashboard/` reference `specs/`.
- 45 files under those areas invoke Git commands.
- 81 skill source files reference `specs/`.
- 25 skill source files prescribe Git-specific lifecycle commands.

The highest-value runtime callers are `project-survey.sh`, `bp-timing.sh`,
`validate-specs-yaml.sh`, `record-cycle-time.sh`, the dashboard, MCP state lookup,
and the survey/kickoff/release/session skills.

## Affected Stories

- e77: Pi integration consumes generated `.pi/skills` and `.pi/prompts`.
- e37: Context distribution must preserve one authored source and generated targets.
- e44: Migration scripts currently derive `SPECS_DIR` directly.
- e47: Installation and project seeding expose runtime configuration to consumers.

## Test Coverage

- Existing golden tests cover migration and generated skill artifacts.
- Existing verification gates detect generated artifact drift.
- Gap: no tests currently exercise a non-default artifact root.
- Gap: no tests currently exercise Jujutsu repository discovery or lifecycle state.

## Risk: High

Both assumptions are cross-cutting public contracts, and many callers lack direct tests.
A single global replacement would conflate contributor-repository paths with consumer
project paths and could corrupt bigpowers' own tracked `specs/` tree.

## Recommended action

Proceed in three independently verifiable slices: introduce a central resolver first,
migrate project-facing artifact paths second, then add a VCS adapter and Jujutsu-specific
lifecycle behavior. Preserve `specs/` and Git defaults throughout.
