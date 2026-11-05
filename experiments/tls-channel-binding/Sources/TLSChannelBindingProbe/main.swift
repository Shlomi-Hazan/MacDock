import Foundation
import Network
import Security
import Dispatch

/// Compile-only and review harness for public TLS metadata APIs.
/// It intentionally does not create a connection, identity, trust record, or pairing session.
@available(macOS 14, iOS 17, *)
enum TLSChannelBindingProbe {
    static let label = "com.macdock.experiment.channel-binding.v1"
    static let context = Data("macdock-channel-binding-context-v1".utf8)
    static let exportLength = 32

    static func canDeriveExporterLikeValue(from metadata: NWProtocolTLS.Metadata) -> Bool {
        let protocolMetadata = metadata.securityProtocolMetadata
        let result: Bool = label.withCString { labelPointer in
            context.withUnsafeBytes { (contextBytes: UnsafeRawBufferPointer) -> Bool in
                guard let contextPointer = contextBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                guard let exported = sec_protocol_metadata_create_secret_with_context(
                    protocolMetadata,
                    label.utf8.count,
                    labelPointer,
                    context.count,
                    contextPointer,
                    exportLength
                ) else {
                    return false
                }
                _ = exported
                return true
            }
        }
        return result
    }

    static func inspectPeerPublicKey(from metadata: NWProtocolTLS.Metadata) -> Bool {
        sec_protocol_metadata_copy_peer_public_key(metadata.securityProtocolMetadata) != nil
    }

    static func inspectPeerCertificateChain(from metadata: NWProtocolTLS.Metadata) -> Bool {
        sec_protocol_metadata_access_peer_certificate_chain(metadata.securityProtocolMetadata) { _ in }
    }

    static func makeFailClosedTLSOptions() -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
        return options
    }
}

@main
struct Main {
    static func main() {
        print("TLS channel-binding API probe compiled; no network connection was opened.")
        print("Public APIs referenced: NWProtocolTLS.Metadata, sec_protocol_metadata_create_secret_with_context, peer public-key and certificate-chain access.")
        print("TLS verification remains required; no trust callback or identity material is configured.")
    }
}
