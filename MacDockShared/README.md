# MacDockShared

`MacDockShared` is the small Foundation-only Swift package shared by the native MacDock targets.

## Protocol framing

The Stage 1 framing foundation uses a four-byte unsigned big-endian length prefix followed by a UTF-8 JSON envelope. The length covers the encoded JSON envelope and excludes the prefix itself. The maximum encoded frame payload is 64 KiB, which is sufficient for control-plane foundation messages while keeping buffering bounded; icon transfer limits remain a later protocol decision.

The envelope contains a protocol version, an ASCII message-type category, an optional request identifier, and a bounded `Data` payload. The 64 KiB encoded JSON frame limit is authoritative on the wire. Because `Data` is represented as Base64 in JSON, a raw payload close to 64 KiB may be rejected after encoding; the raw payload bound is an input guard, not a promise that the entire raw range fits in one frame. JSON encoding uses sorted keys for repeatable fixtures. Unknown JSON fields are ignored by the standard decoder and must not be treated as a security boundary.

`ProtocolFrameDecoder` accepts fragmented input and multiple frames per input. Empty or oversized declarations, malformed envelopes, unsupported versions, and truncated streams produce stable errors. A decoding error fails the current decoder; callers may explicitly call `reset()` to start a new framing session.

This package provides structure and bounds only. Parsing is not authentication or authorization, and it does not create a transport, pairing flow, session identity, replay protection, or remote-control endpoint.
