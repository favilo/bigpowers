# Configurable artifact root across project-facing surfaces

**type:** feat  
**risk:** P1  
**context:** tooling

## Purpose

Make consumer-facing scripts, dashboards, MCP state lookup, and skill guidance resolve
bigpowers artifacts from the configured root instead of assuming `specs/`.

## Requirements

#### MODIFIED: Project artifact location

**Before:** Project-facing tools and skills treat `specs/` as an unconditional literal path.  
**After:** They resolve the configured artifact root; absent configuration remains `specs/`.

#### ADDED: Skill path substitution contract

Generated agent guidance states that every documented `specs/...` path is relative to the
resolved artifact root and must be substituted before reading or writing.

## Acceptance Criteria

1. A fixture configured with `.specs` stores timing and state changes under `.specs` only.
2. Project survey discovers state and release files under `.specs`.
3. Default fixtures continue to use `specs` without configuration.
4. Dashboard and MCP lookups use the same resolver contract.
5. Generated Pi skills include the artifact-root substitution instruction.

## Implementation Steps

1. Migrate state, survey, validation, migration, dashboard, and MCP entry points to the resolver → verify: `bash scripts/test-configurable-specs-root.sh`
2. Add the configuration contract to canonical skill rendering and regenerate targets → verify: `bash scripts/sync-skills.sh --distribute-only && rg -q 'configured artifact root' .pi/skills/using-bigpowers/SKILL.md`
3. Add a guard test against new project-facing hardcoded state paths → verify: `bash scripts/test-configurable-specs-root.sh`

## Verification Script

Run the configurable-root fixture suite, then run skill distribution and confirm generated
Pi guidance contains the shared contract.

## Out of scope

- Moving bigpowers contributor artifacts from this repository's tracked `specs/` tree.
- Automatically migrating an existing cockpit.

## Risks

Contributor-maintenance scripts also contain `specs/` literals. Tests must distinguish those
repository-owned paths from consumer project paths rather than performing a blind replacement.

## Reason for Depth

One rendering-level contract keeps 80 generated skills consistent without duplicating mutable
configuration parsing inside natural-language instructions.

## Slopcheck

No new external packages.
