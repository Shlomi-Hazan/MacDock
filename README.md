# MacDock

MacDock is an independent, native Apple-platform application that turns an iPhone into a customizable Dock and control surface for a Mac over a local network.

## Project status

MacDock is in Stage 0: discovery and feasibility. No production application code exists yet.

The initial MVP targets one Mac and one iPhone. The interactive Dock is expected to operate while the iOS application is in the foreground. The first MVP focuses on securely pairing the devices, displaying a customizable set of Mac applications, and launching or activating those applications from the iPhone.

Touchpad, keyboard, media controls, clipboard synchronization, and other advanced capabilities are intentionally out of scope for the initial MVP.

## Development principles

- Native Swift and SwiftUI development.
- Local-first communication using Apple platform APIs.
- Security and privacy by design.
- Public, issue-driven development through pull requests.
- Experiments are kept separate from production components.
- Decisions are documented and verified against implementation reality.

## Documentation

- [Product requirements](PRD.md)
- [Roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [AI and development-agent guidance](AGENTS.md)
- [Architecture decisions](docs/decisions/)

## License

MacDock is licensed under the MIT License. See [LICENSE](LICENSE).
