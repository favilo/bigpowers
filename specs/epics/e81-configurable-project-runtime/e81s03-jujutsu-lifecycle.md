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

1. `SC-e81s03-P0-01`: A colocated `.jj` + `.git` fixture resolves `jj`, not `git`.
2. `SC-e81s03-P0-02`: Survey reports the current Jujutsu change ID and parent bookmark without detached-HEAD text.
3. `SC-e81s03-P0-03`: Git-only fixtures retain branch, status, recent-log output, and lifecycle guidance.
4. `SC-e81s03-P0-04`: Jujutsu guidance uses `jj status`, `jj log`, stable change IDs, and non-interactive mutation options.
5. `SC-e81s03-P0-05`: Unsupported Git-only operations fail explicitly rather than running against the colocated Git backend.
6. `SC-e81s03-P1-01`: Explicit `git`, `jj`, and `auto` selection returns the requested adapter or an actionable executable/repository error.
7. `SC-e81s03-P1-02`: Project survey renders VCS-neutral state labels and recent history through either adapter.

## Zoom-Out Mandate

- **Purpose:** `project-vcs.sh` owns VCS discovery and read-only lifecycle state; `project-survey.sh` renders that state for session-start consumers; lifecycle skills prescribe safe mutations.
- **Callers:** session-start hooks call `project-survey.sh`; survey, kickoff, session, commit, and release skills consume the VCS contract; verification gates consume their generated artifacts.
- **Contracts:** auto mode prefers Jujutsu in colocated repositories; Git defaults remain byte-compatible where practical; Jujutsu identity uses stable change IDs rather than detached Git HEAD; prescribed mutations never open an editor; unsupported operations fail closed with remediation.

## Define Success

- Colocated discovery selects Jujutsu → verify: `bash scripts/test-project-vcs.sh`
- Jujutsu and Git surveys expose their native identities without cross-interpreting state → verify: `bash scripts/test-project-vcs.sh`
- Canonical and generated lifecycle guidance is VCS-conditional and non-interactive → verify: `bash scripts/sync-skills.sh --distribute-only && bash scripts/test-project-vcs.sh`
- Unsupported Git-only paths fail closed in Jujutsu mode → verify: `bash scripts/test-project-vcs.sh`

## Implementation Steps

1. Add failing temporary-repository fixtures for `SC-e81s03-P0-01` through `SC-e81s03-P0-05` and `SC-e81s03-P1-01` through `SC-e81s03-P1-02` → verify: `bash scripts/test-project-vcs.sh`
2. Implement read-only VCS discovery and state adapters for `SC-e81s03-P0-01`, `SC-e81s03-P0-02`, `SC-e81s03-P0-03`, and `SC-e81s03-P1-01` → verify: `bash scripts/test-project-vcs.sh`
3. Route project survey through the adapter for `SC-e81s03-P1-02` → verify: `bash scripts/test-project-vcs.sh`
4. Add conditional lifecycle guidance and explicit Git-only failures for `SC-e81s03-P0-04` and `SC-e81s03-P0-05` → verify: `bash scripts/sync-skills.sh --distribute-only && bash scripts/test-project-vcs.sh`

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
