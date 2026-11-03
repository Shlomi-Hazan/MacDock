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

The bootstrap uses local review and pattern checks. A dedicated scanner such as Gitleaks will be evaluated before application credentials, certificates, or production workflows are introduced. Any scanner added to CI must be pinned and reviewed as a supply-chain dependency.
