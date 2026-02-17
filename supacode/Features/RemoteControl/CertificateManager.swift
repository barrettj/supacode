// Created by Barrett Jacobsen

import Foundation
import Network
import Security

private let logger = SupaLogger("CertificateManager")

enum CertificateManager {
  private static let identityLabel = "com.supacode.remote-control.identity"
  private static let keychainPassword = "supacode-ephemeral"
  private static var temporaryKeychain: SecKeychain?

  /// Returns TLS options configured with a fresh self-signed identity.
  static func tlsOptions() throws -> NWProtocolTLS.Options {
    let identity = try generateIdentityInTemporaryKeychain()
    let options = NWProtocolTLS.Options()
    let secIdentity = sec_identity_create(identity)!
    sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
    sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv12)
    return options
  }

  /// Removes the temporary keychain file.
  static func cleanup() {
    if let keychain = temporaryKeychain {
      SecKeychainDelete(keychain)
      temporaryKeychain = nil
    }
    try? FileManager.default.removeItem(atPath: keychainPath)
  }

  // MARK: - Private

  private static var keychainPath: String {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return cacheDir.appendingPathComponent("supacode-tls.keychain-db").path
  }

  private static func generateIdentityInTemporaryKeychain() throws -> SecIdentity {
    // Clean up any previous keychain
    cleanup()

    // Save the current search list before creating (SecKeychainCreate adds to it automatically)
    var originalSearchList: CFArray?
    SecKeychainCopySearchList(&originalSearchList)

    // Create a temporary keychain file with a known password (no user interaction)
    let path = keychainPath
    var keychain: SecKeychain?
    let password = keychainPassword
    var status = SecKeychainCreate(path, UInt32(password.utf8.count), password, false, nil, &keychain)
    guard status == errSecSuccess || status == errSecDuplicateKeychain, let kc = keychain else {
      throw CertificateError.keychainCreateFailed(status)
    }

    // Restore the original search list so macOS doesn't scan our keychain
    if let original = originalSearchList {
      SecKeychainSetSearchList(original)
    }

    // Disable auto-lock so the keychain never locks and prompts
    var settings = SecKeychainSettings(version: UInt32(SEC_KEYCHAIN_SETTINGS_VERS1), lockOnSleep: false, useLockInterval: false, lockInterval: 0)
    SecKeychainSetSettings(kc, &settings)

    temporaryKeychain = kc

    // 1. Generate P-256 private key in the temporary keychain
    let keyAttributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrLabel as String: identityLabel,
      kSecUseKeychain as String: kc,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrLabel as String: identityLabel,
      ],
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
      throw CertificateError.keyGenerationFailed(error?.takeRetainedValue() as? Error)
    }

    // 2. Create self-signed certificate
    let certificate = try createSelfSignedCertificate(privateKey: privateKey)

    // 3. Store certificate in the temporary keychain
    let certAddQuery: [String: Any] = [
      kSecClass as String: kSecClassCertificate,
      kSecValueRef as String: certificate,
      kSecAttrLabel as String: identityLabel,
      kSecUseKeychain as String: kc,
    ]
    let certStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
    guard certStatus == errSecSuccess || certStatus == errSecDuplicateItem else {
      throw CertificateError.keychainStoreFailed(certStatus)
    }

    // 4. Load the identity (cert + key pair) from the temporary keychain
    let searchList = [kc] as CFArray
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrLabel as String: identityLabel,
      kSecMatchSearchList as String: searchList,
      kSecReturnRef as String: true,
    ]
    var result: CFTypeRef?
    status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let identity = result else {
      throw CertificateError.identityLoadFailed
    }
    return (identity as! SecIdentity)  // swiftlint:disable:this force_cast
  }

  private static func createSelfSignedCertificate(privateKey: SecKey) throws -> SecCertificate {
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw CertificateError.publicKeyExtractionFailed
    }

    // Build a minimal self-signed X.509 v3 certificate using ASN.1 DER encoding
    let subject: [UInt8] = buildDistinguishedName(commonName: "Supacode Remote Control")
    let serialNumber = UInt64.random(in: 1...UInt64.max)

    // Validity: now to 10 years from now
    let now = Date()
    let tenYearsFromNow = Calendar.current.date(byAdding: .year, value: 10, to: now)!
    let notBefore = utcTime(from: now)
    let notAfter = utcTime(from: tenYearsFromNow)

    // Get public key DER data
    var publicKeyError: Unmanaged<CFError>?
    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &publicKeyError) as Data? else {
      throw CertificateError.publicKeyExtractionFailed
    }

    // Build TBS (To Be Signed) Certificate
    let tbs = buildTBSCertificate(
      serialNumber: serialNumber,
      subject: subject,
      notBefore: notBefore,
      notAfter: notAfter,
      publicKeyData: publicKeyData
    )

    // Sign with ECDSA-SHA256
    var signError: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(
        privateKey,
        .ecdsaSignatureMessageX962SHA256,
        Data(tbs) as CFData,
        &signError
      ) as Data?
    else {
      throw CertificateError.signingFailed(signError?.takeRetainedValue() as? Error)
    }

    // Build complete certificate
    let certDER = buildCertificate(tbs: tbs, signature: [UInt8](signature))

    guard let certificate = SecCertificateCreateWithData(nil, Data(certDER) as CFData) else {
      throw CertificateError.certificateCreationFailed
    }
    return certificate
  }

  // MARK: - ASN.1 DER Helpers

  private static func buildDistinguishedName(commonName: String) -> [UInt8] {
    let cnBytes = [UInt8](commonName.utf8)
    // OID for commonName: 2.5.4.3
    let oid: [UInt8] = [0x55, 0x04, 0x03]
    let attrValue = derTag(0x0C, cnBytes)  // UTF8String
    let attrTypeAndValue = derSequence(derTag(0x06, oid) + attrValue)
    let rdn = derSet([attrTypeAndValue])
    return derSequence(rdn)
  }

  private static func buildTBSCertificate(
    serialNumber: UInt64,
    subject: [UInt8],
    notBefore: [UInt8],
    notAfter: [UInt8],
    publicKeyData: Data
  ) -> [UInt8] {
    // Version: v3 (2), explicit tag [0]
    let version = derExplicit(0, derInteger(2))

    // Serial number
    let serial = derInteger(serialNumber)

    // Signature algorithm: ecdsa-with-SHA256 (1.2.840.10045.4.3.2)
    let sigAlgOID: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]
    let sigAlg = derSequence(derTag(0x06, sigAlgOID))

    // Issuer = Subject (self-signed)
    let issuer = subject

    // Validity
    let validity = derSequence(notBefore + notAfter)

    // SubjectPublicKeyInfo for EC P-256
    // Algorithm: id-ecPublicKey (1.2.840.10045.2.1) with P-256 curve (1.2.840.10045.3.1.7)
    let ecPubKeyOID: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
    let p256OID: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
    let keyAlg = derSequence(derTag(0x06, ecPubKeyOID) + derTag(0x06, p256OID))
    let keyBits = derBitString([UInt8](publicKeyData))
    let spki = derSequence(keyAlg + keyBits)

    return derSequence(version + serial + sigAlg + issuer + validity + subject + spki)
  }

  private static func buildCertificate(tbs: [UInt8], signature: [UInt8]) -> [UInt8] {
    let sigAlgOID: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]
    let sigAlg = derSequence(derTag(0x06, sigAlgOID))
    let sigBits = derBitString(signature)
    return derSequence(tbs + sigAlg + sigBits)
  }

  private static func utcTime(from date: Date) -> [UInt8] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMddHHmmss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let bytes = [UInt8](formatter.string(from: date).utf8)
    return derTag(0x17, bytes)  // UTCTime
  }

  private static func derTag(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
    [tag] + derLength(content.count) + content
  }

  private static func derLength(_ length: Int) -> [UInt8] {
    if length < 128 {
      return [UInt8(length)]
    } else if length < 256 {
      return [0x81, UInt8(length)]
    } else {
      return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
    }
  }

  private static func derSequence(_ content: [UInt8]) -> [UInt8] {
    derTag(0x30, content)
  }

  private static func derSet(_ items: [[UInt8]]) -> [UInt8] {
    derTag(0x31, items.flatMap { $0 })
  }

  private static func derInteger(_ value: UInt64) -> [UInt8] {
    var bytes: [UInt8] = []
    var v = value
    repeat {
      bytes.insert(UInt8(v & 0xFF), at: 0)
      v >>= 8
    } while v > 0
    // Ensure positive (leading bit must be 0)
    if bytes[0] & 0x80 != 0 {
      bytes.insert(0x00, at: 0)
    }
    return derTag(0x02, bytes)
  }

  private static func derBitString(_ content: [UInt8]) -> [UInt8] {
    derTag(0x03, [0x00] + content)  // 0 unused bits
  }

  private static func derExplicit(_ tag: Int, _ content: [UInt8]) -> [UInt8] {
    derTag(0xA0 | UInt8(tag), content)
  }
}

enum CertificateError: Error {
  case keyGenerationFailed(Error?)
  case publicKeyExtractionFailed
  case signingFailed(Error?)
  case certificateCreationFailed
  case keychainStoreFailed(OSStatus)
  case identityLoadFailed
  case keychainCreateFailed(OSStatus)
}
