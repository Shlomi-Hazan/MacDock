# Security Policy

## Scope

MacDock is intended to communicate between a Mac and an iPhone over a local network. Local network reachability is not considered authentication.

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
