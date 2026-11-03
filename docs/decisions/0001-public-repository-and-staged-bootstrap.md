# ADR 0001: Public Repository and Staged Bootstrap

- Status: Accepted
- Date: 2026-11-03
- Decision owner: MacDock maintainer

## Context

MacDock is intended to be an openly developed project. The repository must be public from the beginning, while the initial branch must remain small and free of secrets, application code, and unvalidated architectural claims.

## Decision

Create the public repository after a local documentation and security review. Establish a minimal bootstrap CI workflow first. Enable repository protection after the workflow has produced a verified successful check. Add Xcode build and test checks only after an Xcode project exists.

Stage 0 experiments will be tracked publicly but kept separate from production application targets.

## Consequences

- The engineering history is public from the start.
- Initial CI validates repository integrity rather than application behavior.
- Required checks can be introduced without a circular dependency.
- The maintainer can merge personal pull requests without requiring a second reviewer, while still requiring pull requests and successful CI.
