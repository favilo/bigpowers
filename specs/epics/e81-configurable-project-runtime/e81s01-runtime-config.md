# Project runtime configuration resolver

**type:** feat  
**risk:** P1  
**context:** tooling

## Purpose

Resolve project-local bigpowers settings once so scripts and generated agent guidance
share the same defaults, validation, and override precedence.

## Requirements

#### ADDED: Persistent project runtime configuration

A project may define `.bigpowers/config.yaml` with `specs_dir` and `vcs`. Environment
variables override file settings. Missing configuration preserves current behavior.

#### ADDED: Safe configuration values

`specs_dir` accepts a project-relative or absolute directory path. `vcs` accepts only
`auto`, `git`, or `jj`. Invalid values fail with the offending value and remediation.

## Acceptance Criteria

1. Given no configuration, resolving the artifact root returns `specs`.
2. Given `.bigpowers/config.yaml` with `specs_dir: .specs`, resolving returns `.specs`.
3. Given `BIGPOWERS_SPECS_DIR`, it overrides the file value.
4. Given `vcs: auto`, `.jj` takes precedence over `.git` in colocated repositories.
5. Given an invalid VCS value, resolution fails with an actionable error.

## Implementation Steps

1. Add the dependency-free Bash 3.2 resolver and path helpers → verify: `bash scripts/test-project-runtime.sh`
2. Add isolated fixtures for defaults, file settings, environment overrides, and invalid values → verify: `bash scripts/test-project-runtime.sh`

## Verification Script

Run `bash scripts/test-project-runtime.sh` and confirm every fixture passes.

## Out of scope

- Rewriting project files during configuration.
- Adding third-party YAML dependencies.

## Risks

Naive YAML parsing can imply support for syntax the resolver does not understand. The
configuration format is intentionally limited to top-level scalar keys and documented as such.

## Reason for Depth

A shared resolver prevents dozens of scripts from implementing conflicting precedence and
validation rules.

## Slopcheck

No new external packages.
