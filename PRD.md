# MacDock Product Requirements

## Purpose

MacDock provides an iPhone-based Dock for launching and activating applications on a paired Mac over the local network.

## Initial user

The initial user operates one Apple Silicon MacBook Pro and one iPhone on a trusted local network.

## MVP goals

1. Discover one Mac from the iPhone on the local network.
2. Pair the devices using a user-confirmed secure flow.
3. Display a customizable list of Mac applications on the iPhone.
4. Add, remove, and reorder Dock items.
5. Launch a selected application on the Mac.
6. Activate an already-running application when technically supported and permitted.
7. Display connection, loading, and error states.
8. Reconnect after ordinary network interruptions.

## Product constraints

- The iPhone Dock is interactive while the iOS application is in the foreground.
- QR code discovery or setup is preferred, but a QR code is not authentication by itself.
- The first release supports one Mac and one iPhone.
- Communication is local-first; no cloud service is required for the MVP.

## Out of scope for the MVP

- Touchpad input.
- Keyboard input.
- Media and volume controls.
- Clipboard synchronization.
- Multiple Mac support.
- Profiles, groups, and advanced visual customization.
- Always-on background Dock behavior on iOS.
