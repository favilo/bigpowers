# Plan consistency check exits during verify extraction

## Symptom

`plan-consistency-check.sh` exits with status 1 immediately after assigning the first
story verify command, without printing findings.

## Reproduction

Run the consistency check in a repository where `extract-story-verify.py` emits enough
records that `awk ... exit` closes the pipe before Python finishes writing.

## Root cause

The script enables `set -o pipefail`. Its `awk` command exits after the first matching
record, which can give the Python producer a broken pipe. The command substitution then
returns non-zero and `set -e` aborts the gate.

## Fix plan

Consume the complete producer stream while retaining only the first matching command.
Verify by rerunning the e81 capsule consistency check and the verification gates.
