import CryptoKit
import Foundation
import Network
import Security

/// A one-session TLS identity for the LAN listener: ECDSA P-256, self-signed, SAN bound
/// to the current Wi-Fi addresses. Browsers will warn because there is no public CA;
/// the SHA-256 fingerprint in the app is how a person can check they accepted the right cert.
struct LANWebTLSIdentity {
    let secIdentity: SecIdentity
    let certificate: SecCertificate
    let certificateDER: Data
    let fingerprint: String
    let keyTag: Data
    let keychainLabel: String

    enum GenerationError: Error {
        case keyGenerationFailed
        case publicKeyExportFailed
        case signatureFailed
        case invalidCertificate
        case identityNotFoundInKeychain
    }

    /// Builds a fresh key + certificate and stores them in the Keychain long enough for
    /// Network.framework to serve TLS. Call `removeFromKeychain()` when the server stops.
    static func make(ipAddresses: [String], dnsNames: [String] = ["localhost"]) throws -> LANWebTLSIdentity {
        let tag = Data(UUID().uuidString.utf8)
        let label = "FileVault.LAN.TLS.\(UUID().uuidString)"

        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw GenerationError.keyGenerationFailed
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicBits = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            deleteKey(tag: tag)
            throw GenerationError.publicKeyExportFailed
        }

        let now = Date()
        let der: Data
        do {
            der = try SelfSignedCertificate.der(
                publicKeyBits: publicBits,
                privateKey: privateKey,
                commonName: "File Vault",
                ipAddresses: ipAddresses,
                dnsNames: dnsNames,
                notBefore: now.addingTimeInterval(-300),
                notAfter: now.addingTimeInterval(60 * 60 * 24 * 7)
            )
        } catch {
            deleteKey(tag: tag)
            throw error
        }

        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            deleteKey(tag: tag)
            throw GenerationError.invalidCertificate
        }

        do {
            let identity = try storeIdentity(certificate: certificate, tag: tag, label: label)
            return LANWebTLSIdentity(
                secIdentity: identity,
                certificate: certificate,
                certificateDER: der,
                fingerprint: fingerprint(of: der),
                keyTag: tag,
                keychainLabel: label
            )
        } catch {
            deleteKey(tag: tag)
            Self.deleteCertificate(label: label)
            throw error
        }
    }

    func listenerParameters() -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let tcp = NWProtocolTCP.Options()
        let identity = sec_identity_create(secIdentity)!
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
        sec_protocol_options_set_peer_authentication_required(tls.securityProtocolOptions, false)
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        return parameters
    }

    func removeFromKeychain() {
        Self.deleteCertificate(label: keychainLabel)
        Self.deleteKey(tag: keyTag)
    }

    /// SHA-256 of the certificate DER, grouped for display next to the URL.
    static func fingerprint(of der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// True when `trust` presents exactly this certificate — used by the in-app
    /// background uploader, which would otherwise reject a self-signed LAN cert.
    func matches(_ trust: SecTrust) -> Bool {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let presented = chain.first else { return false }
        return (SecCertificateCopyData(presented) as Data) == certificateDER
    }

    // MARK: - Keychain

    private static func storeIdentity(certificate: SecCertificate, tag: Data, label: String) throws -> SecIdentity {
        let add: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: label,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(add as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw GenerationError.identityNotFoundInKeychain
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let copyStatus = SecItemCopyMatching(query as CFDictionary, &result)
        guard copyStatus == errSecSuccess, let identities = result as? [SecIdentity] else {
            throw GenerationError.identityNotFoundInKeychain
        }

        let expected = SecCertificateCopyData(certificate) as Data
        for identity in identities {
            var attached: SecCertificate?
            SecIdentityCopyCertificate(identity, &attached)
            if let attached, (SecCertificateCopyData(attached) as Data) == expected {
                return identity
            }
        }
        _ = tag
        throw GenerationError.identityNotFoundInKeychain
    }

    private static func deleteKey(tag: Data) {
        SecItemDelete([
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ] as CFDictionary)
    }

    private static func deleteCertificate(label: String) {
        SecItemDelete([
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label
        ] as CFDictionary)
    }
}

// MARK: - Minimal X.509 v3 (ECDSA P-256, SHA-256)

private enum SelfSignedCertificate {
    static func der(
        publicKeyBits: Data,
        privateKey: SecKey,
        commonName: String,
        ipAddresses: [String],
        dnsNames: [String],
        notBefore: Date,
        notAfter: Date
    ) throws -> Data {
        let tbs = tbsCertificate(
            publicKeyBits: publicKeyBits,
            commonName: commonName,
            ipAddresses: ipAddresses,
            dnsNames: dnsNames,
            notBefore: notBefore,
            notAfter: notAfter
        )
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            tbs as CFData,
            &error
        ) as Data? else {
            throw LANWebTLSIdentity.GenerationError.signatureFailed
        }
        return DER.sequence([
            tbs,
            DER.sequence([DER.objectIdentifier(OID.ecdsaWithSHA256)]),
            DER.bitString(signature)
        ])
    }

    private static func tbsCertificate(
        publicKeyBits: Data,
        commonName: String,
        ipAddresses: [String],
        dnsNames: [String],
        notBefore: Date,
        notAfter: Date
    ) -> Data {
        var serial = Data(count: 8)
        serial.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!) }

        let name = directoryName(commonName)
        let spki = DER.sequence([
            DER.sequence([
                DER.objectIdentifier(OID.ecPublicKey),
                DER.objectIdentifier(OID.prime256v1)
            ]),
            DER.bitString(publicKeyBits)
        ])

        return DER.sequence([
            DER.tagged(0xA0, DER.unsignedInteger(Data([0x02]))),
            DER.unsignedInteger(serial),
            DER.sequence([DER.objectIdentifier(OID.ecdsaWithSHA256)]),
            name,
            DER.sequence([DER.utcTime(notBefore), DER.utcTime(notAfter)]),
            name,
            spki,
            DER.tagged(0xA3, extensions(ipAddresses: ipAddresses, dnsNames: dnsNames))
        ])
    }

    private static func directoryName(_ commonName: String) -> Data {
        DER.sequence([
            DER.set([
                DER.sequence([
                    DER.objectIdentifier(OID.commonName),
                    DER.utf8(commonName)
                ])
            ])
        ])
    }

    private static func extensions(ipAddresses: [String], dnsNames: [String]) -> Data {
        var san: [Data] = []
        for name in dnsNames {
            san.append(DER.tagged(0x82, Data(name.utf8)))
        }
        for address in ipAddresses {
            if let octets = ipv4Octets(address) {
                san.append(DER.tagged(0x87, octets))
            }
        }
        let sanExtension = DER.sequence([
            DER.objectIdentifier(OID.subjectAltName),
            DER.octetString(DER.sequence(san))
        ])
        let keyUsage = DER.sequence([
            DER.objectIdentifier(OID.keyUsage),
            DER.tagged(0x01, Data([0xFF])),
            DER.octetString(DER.bitString(Data([0x80])))
        ])
        let extKeyUsage = DER.sequence([
            DER.objectIdentifier(OID.extKeyUsage),
            DER.octetString(DER.sequence([DER.objectIdentifier(OID.serverAuth)]))
        ])
        return DER.sequence([sanExtension, keyUsage, extKeyUsage])
    }

    private static func ipv4Octets(_ string: String) -> Data? {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return nil }
        let bytes = parts.compactMap { UInt8($0) }
        guard bytes.count == 4 else { return nil }
        return Data(bytes)
    }
}

private enum OID {
    static let ecdsaWithSHA256: [UInt] = [1, 2, 840, 10045, 4, 3, 2]
    static let ecPublicKey: [UInt] = [1, 2, 840, 10045, 2, 1]
    static let prime256v1: [UInt] = [1, 2, 840, 10045, 3, 1, 7]
    static let commonName: [UInt] = [2, 5, 4, 3]
    static let subjectAltName: [UInt] = [2, 5, 29, 17]
    static let keyUsage: [UInt] = [2, 5, 29, 15]
    static let extKeyUsage: [UInt] = [2, 5, 29, 37]
    static let serverAuth: [UInt] = [1, 3, 6, 1, 5, 5, 7, 3, 1]
}

private enum DER {
    static func tagged(_ tag: UInt8, _ content: Data) -> Data {
        var result = Data([tag])
        result.append(lengthField(content.count))
        result.append(content)
        return result
    }

    static func sequence(_ parts: [Data]) -> Data {
        tagged(0x30, parts.reduce(into: Data(), { $0.append($1) }))
    }

    static func set(_ parts: [Data]) -> Data {
        tagged(0x31, parts.reduce(into: Data(), { $0.append($1) }))
    }

    static func octetString(_ content: Data) -> Data {
        tagged(0x04, content)
    }

    static func utf8(_ string: String) -> Data {
        tagged(0x0C, Data(string.utf8))
    }

    static func bitString(_ bytes: Data) -> Data {
        var content = Data([0x00])
        content.append(bytes)
        return tagged(0x03, content)
    }

    static func unsignedInteger(_ bytes: Data) -> Data {
        var content = bytes
        while content.count > 1 && content[0] == 0 { content.removeFirst() }
        if content.isEmpty { content = Data([0]) }
        if content[0] & 0x80 != 0 { content.insert(0, at: 0) }
        return tagged(0x02, content)
    }

    static func utcTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        return tagged(0x17, Data(formatter.string(from: date).utf8))
    }

    static func objectIdentifier(_ oid: [UInt]) -> Data {
        var content = Data([UInt8(oid[0] * 40 + oid[1])])
        for component in oid.dropFirst(2) {
            content.append(base128(component))
        }
        return tagged(0x06, content)
    }

    private static func base128(_ value: UInt) -> Data {
        if value < 128 { return Data([UInt8(value)]) }
        var bytes: [UInt8] = []
        var remaining = value
        bytes.insert(UInt8(remaining & 0x7F), at: 0)
        remaining >>= 7
        while remaining > 0 {
            bytes.insert(UInt8((remaining & 0x7F) | 0x80), at: 0)
            remaining >>= 7
        }
        return Data(bytes)
    }

    private static func lengthField(_ count: Int) -> Data {
        if count < 128 { return Data([UInt8(count)]) }
        var bytes: [UInt8] = []
        var value = count
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}
