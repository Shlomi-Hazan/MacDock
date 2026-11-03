# AGENTS.md

## Project language policy

- User-facing collaboration is conducted in Hebrew.
- Source code, code comments, documentation, GitHub Issues, pull requests, and commit messages are written in English.

## Engineering rules

- Do not publish secrets, credentials, certificates, private device identifiers, or personal data.
- Do not push directly to `main` after repository protection is enabled.
- Associate meaningful implementation work with a GitHub Issue when practical.
- Keep experiments separate from production targets and label them clearly.
- Do not claim that a test, build, deployment, or remote action succeeded without verification.
- Prefer native Apple frameworks and the smallest maintainable design.
- Record significant architectural decisions as ADRs.
- Update documentation and tracking when verified project state changes.

## Scope control

The initial MVP is limited to one Mac, one iPhone, secure local pairing, a customizable application launcher, and connection state handling. Advanced controls require explicit scope approval.
