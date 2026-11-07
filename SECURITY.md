# Security Policy

## Scope

MacDock is intended to communicate between a Mac and an iPhone over a local network. Local network reachability is not considered authentication.

## Expanded MVP security boundaries

The proposed Mac Control Center adds operation classes with different impact. Peer authentication is necessary but does not authorize every capability. Production handlers must use deny-by-default capability negotiation and operation-level policy as described in [the proposed authorization and privacy requirements](docs/security/expanded-mvp-authorization-and-privacy-requirements.md).

- Dock launch and activation must use validated logical application identifiers; arbitrary paths, shell commands, and unrestricted process control remain prohibited.
- Audio, media, battery, and network telemetry must minimize fields, expose freshness and unavailable states, and avoid unnecessary device identifiers. Speed tests require explicit consent and bounded data use.
- Pointer control requires explicit macOS permission and visible, revocable activation. It must not monitor or record input.
- Keyboard input starts as constrained, user-initiated text insertion. It must respect Secure Input and protected applications and must never become keylogging or an input-monitoring bypass.
- Clipboard transfer is explicit and one-shot in the baseline MVP. Do not poll, silently mirror, log, or retain clipboard contents beyond the documented operation.
- Disconnects, session changes, revocation, and lost acknowledgments invalidate sensitive grants. Non-idempotent launch, input, clipboard, and speed-test operations must not be automatically replayed.
- No private Apple APIs, hidden background operation, privilege escalation, or silent permission escalation may be introduced.

## Development requirements

- Never commit credentials, private keys, certificates, tokens, or private device identifiers.
- Store long-lived secrets in platform security services such as Keychain where applicable.
- Treat Bonjour as discovery only.
- Require explicit peer authentication after discovery.
- Keep pairing, transport, and trust decisions documented.
- Avoid logging sensitive payloads or identifiers.

## Reporting a vulnerability

Do not disclose a suspected vulnerability in a public issue. Use the repository's private security reporting mechanism once it is configured. Until then, contact the maintainer privately before disclosure.

## Scanner policy

The Repository Integrity workflow checks changed file names for common credential and signing-material extensions. The Foundation Validation workflow also runs Gitleaks v2.3.9, pinned to an immutable commit, against repository history without uploading artifacts or commenting on pull requests. These checks are guardrails, not guarantees that every sensitive value will be detected. Scanner updates require review of the upstream action, commit pin, permissions, and false-positive behavior.
