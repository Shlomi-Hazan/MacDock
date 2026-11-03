# Development Workflow

This document defines the lightweight operating procedure for public MacDock development. GitHub state is evidence of verified progress, not a prediction of intended work.

## Task intake

Before changing files, identify the relevant Issue, scope, dependencies, acceptance criteria, affected platforms, security implications, and documentation impact. Research tasks must state the question, sources or experiment, result, limitations, and follow-up decision. Keep prototype code isolated from production targets.

## Branch and pull request lifecycle

1. Start from an up-to-date `main` and create one focused branch.
2. Keep the Issue, branch, commits, and PR narrowly aligned.
3. Update relevant documentation in the same PR when the implementation changes its truth.
4. Run local checks, inspect the full diff, and open a PR using the repository template.
5. Merge only after required CI checks pass and the PR review confirms acceptance criteria.

## Project and Issue synchronization

- `Backlog`: identified but not ready to execute.
- `Ready`: acceptance criteria and dependencies are clear.
- `In Progress`: work has started on a branch.
- `In Review`: a PR is open and validation is available.
- `Blocked`: a concrete dependency, permission, or failed operation prevents progress; record it in the Issue.
- `Done`: acceptance criteria are met and the closing PR or evidence is verified.

Update the Issue, milestone, and Project item after a verified state change. If an update fails, leave the repository evidence intact, report the exact failed operation, and retry only after the cause is understood. Do not close Issues or milestones based solely on an intended merge or an unverified local result.

## Documentation decision

Use the synchronization matrix in `AGENTS.md`. Do not mechanically touch unrelated documents. Every PR must state which documentation, ADR, roadmap, and tracking records were updated or why they were not applicable.

## Definition of Done

A task is complete when the deliverable or research result exists; relevant validation, security review, and complete-diff inspection are recorded; affected documentation is synchronized; CI status is verified; and GitHub tracking reflects the verified state. The final report must include commands or links that support the claim and list unresolved risks.

## Approval boundaries

Routine scoped work can proceed without additional approval. Ask before publishing sensitive information, performing destructive actions, weakening security controls, making significant architecture or scope changes, changing authentication/security policy, or releasing/deploying production artifacts.
