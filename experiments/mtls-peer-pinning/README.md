# Mutual TLS and Peer-Pinning Feasibility Experiment

This is an isolated macOS-only feasibility experiment for Issue #52. It tests public Network.framework and Security.framework APIs for TLS 1.3 mutual certificate authentication and explicit peer pinning.

It does not implement MacDock pairing, production identity, durable trust, authorization, QR UX, or application-control endpoints. All identities are generated locally outside the repository.

## Local identity generation

Generate two short-lived, self-signed test identities under a temporary directory:

```sh
experiments/mtls-peer-pinning/generate-test-identities.sh /private/tmp/macdock-mtls-fixture
```

The script refuses to overwrite an existing directory and prints only public certificate fingerprints. Keep all private keys, PKCS#12 files, and passwords under the temporary directory.

## Mac-to-Mac probe

```sh
swift run --package-path experiments/mtls-peer-pinning MTLSPeerPinningProbe \
  --server-p12 /private/tmp/macdock-mtls-fixture/server.identity.p12 \
  --server-password-file /private/tmp/macdock-mtls-fixture/server.password \
  --server-anchor /private/tmp/macdock-mtls-fixture/server.cer.der \
  --server-pin-file /private/tmp/macdock-mtls-fixture/server.fingerprint \
  --client-p12 /private/tmp/macdock-mtls-fixture/client.identity.p12 \
  --client-password-file /private/tmp/macdock-mtls-fixture/client.password \
  --client-anchor /private/tmp/macdock-mtls-fixture/client.cer.der \
  --client-pin-file /private/tmp/macdock-mtls-fixture/client.fingerprint
```

The positive run must report TLS ready and both peer pins accepted. The negative runs replace one pin or anchor with the other public fixture and must report a failed handshake or failed pin verification without reporting an authenticated peer.

## Security boundary

TLS readiness means only that the configured TLS handshake completed. The probe reports peer certificate validation and pinning separately. It never creates a trust record or an authorization grant. The state-machine tests demonstrate that an explicit confirmation is required before a test state can become `committed`.
