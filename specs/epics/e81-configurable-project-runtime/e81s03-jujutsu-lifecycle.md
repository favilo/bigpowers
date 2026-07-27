# Native Jujutsu lifecycle state

**type:** feat  
**risk:** P0  
**context:** tooling

## Purpose

Report and operate on Jujutsu working-copy state without interpreting colocated Git's detached
HEAD as a branch error.

## Requirements

#### MODIFIED: Version-control discovery

**Before:** Project-facing runtime scripts and skills assume Git and use branches and commit
hashes as the primary identity.  
**After:** `vcs: auto` detects `.jj` before `.git`; Jujutsu mode uses stable change IDs,
bookmarks, workspaces, and non-interactive commands. Git behavior remains unchanged.

#### ADDED: Explicit VCS override

`BIGPOWERS_VCS` or `.bigpowers/config.yaml` may select `git`, `jj`, or `auto`.

## Acceptance Criteria

1. A colocated fixture resolves `jj`, not `git`.
2. Survey reports the current Jujutsu change ID and parent bookmark without detached-HEAD text.
3. Guidance uses `jj status`, `jj log`, and change IDs in Jujutsu mode.
4. All mutating Jujutsu commands prescribed to agents include non-interactive message/options.
5. Git fixtures retain their existing output and lifecycle guidance.
6. Unsupported Git-only operations fail explicitly rather than silently running against the
   colocated Git backend.

## Implementation Steps

1. Add a read-only VCS adapter and Git/Jujutsu fixture tests → verify: `bash scripts/test-project-vcs.sh`
2. Route project survey through the adapter → verify: `bash scripts/test-project-vcs.sh`
3. Add conditional Jujutsu procedures to survey, kickoff, session, commit, and release skills → verify: `bash scripts/sync-skills.sh --distribute-only && bash scripts/test-project-vcs.sh`
4. Document unsupported Git-only scripts and fail fast when Jujutsu mode selects them → verify: `bash scripts/test-project-vcs.sh`

## Verification Script

Create temporary Git, Jujutsu, and colocated repositories; run the adapter and survey in each;
confirm stable change identity and backwards-compatible Git output.

## Out of scope

- Reimplementing every Git plumbing operation inside Jujutsu.
- Changing bigpowers contributor release automation, which remains Git/GitHub based.
- Supporting non-Git-backed Jujutsu remotes.

## Risks

Bookmarks are not branches and do not advance automatically. Guidance must never translate a
Git branch command mechanically when the equivalent requires an explicit bookmark decision.

## Reason for Depth

A VCS adapter isolates incompatible identity models and prevents Git/Jujutsu conditionals from
spreading across every lifecycle script.

## Slopcheck

No new external packages; Jujutsu is an optional external executable selected by configuration.
