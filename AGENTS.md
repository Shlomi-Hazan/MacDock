# AGENTS.md

## Project contract

MacDock is a native Apple-platform application that uses an iPhone as a local-network Dock for one Mac. The initial MVP is limited to secure pairing, a customizable application launcher, and connection state handling for one Mac and one iPhone. Touchpad, keyboard, media, clipboard, multi-Mac support, and other advanced controls require explicit scope approval.

- Prefer Swift, SwiftUI, AppKit, Network.framework, Bonjour, Keychain, and Apple system APIs.
- Keep platform boundaries, experiments, and production components explicit.
- Use the smallest maintainable design; record significant architecture decisions as ADRs.
- Treat local-network reachability as discovery, never as authentication.
- Do not publish secrets, credentials, certificates, private device identifiers, or personal data.
- User-facing collaboration is in Hebrew. Source code, comments, documentation, Issues, PRs, and commits are in English.
- Development is public and issue-driven. Do not push directly to `main` while protection is enabled.

## Task execution

For every meaningful task:

1. Read the relevant project documents and this contract.
2. Verify the Issue, branch, PR, and Project state when GitHub access is available.
3. Identify dependencies, affected components, and acceptance criteria.
4. Make focused changes on a dedicated branch.
5. Run proportionate validation and inspect the complete diff.
6. Review affected documentation and apply the synchronization rules below.
7. Synchronize verified GitHub tracking records; report any failed operation.
8. Report evidence, unresolved work, and documentation/tracking updates.

Detailed procedures and status transitions are defined in [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md).

## Documentation synchronization

Update only documents relevant to the change, and explicitly report justified non-updates.

| Change | Review or update |
| --- | --- |
| Product requirements | `PRD.md`, `README.md`, related Issues |
| Architecture or boundaries | `ARCHITECTURE.md` when present, ADRs, affected diagrams |
| Roadmap or scope | `ROADMAP.md`, milestone, Project item |
| Feature behavior | Feature documentation, tests, related Issue |
| Security or privacy | `SECURITY.md`, threat model, relevant ADRs |
| Development workflow or CI | `AGENTS.md`, `CONTRIBUTING.md`, workflow files |
| Release behavior | `CHANGELOG.md`, release documentation |
| Milestone completion | Acceptance review, Issues, Project status, roadmap |

## GitHub synchronization

- Associate meaningful work with an Issue when practical; record dependencies explicitly.
- Use a focused branch and PR. A PR must identify its Issue, acceptance criteria, validation, and documentation impact.
- Move Project status only after the corresponding state is verified. Use `Blocked` with a concrete dependency or failed operation.
- Close an Issue only after its acceptance criteria are satisfied and the closing PR or evidence is verified.
- Mark a milestone complete only after all required Issues, acceptance criteria, Project status, and roadmap state agree.
- Never claim a PR is merged, CI is successful, or tracking is synchronized without direct verification.
- If GitHub synchronization fails, report the exact operation and recovery step; do not conceal partial state.

## Definition of Done

A task is done only when its deliverable or research result is present, relevant tests or validation are recorded, security and privacy implications are reviewed, affected documentation is synchronized or explicitly deemed not applicable, CI results are checked, GitHub tracking reflects verified reality, and the final report includes evidence and remaining risks.

## Approval boundaries

Routine implementation, testing, documentation, and normal tracking updates may proceed under an approved task. Explicit approval is required before publishing sensitive information, destructive repository actions, weakening security or branch protection, significant architecture changes, major scope expansion, production releases, or changes to authentication/security policy.
