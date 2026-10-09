import Foundation
import CryptoKit
import CommonCrypto

/// ESP-IDF **protocomm** Security1 session: X25519 ECDH → SHA256 →
/// AES-256-CTR. Handshake messages flow in two steps on the `prov-session`
/// GATT characteristic; after Step 1 verifies, the same AES-CTR state is
/// reused for all subsequent command traffic (both encrypt and decrypt
/// operations advance the counter).
///
/// Key derivation (confirmed against `CEnhSecurity1::ProcessStep0Response`
/// disassembly):
///
///     aes_key = X25519(client_priv, device_pub)  XOR  SHA256(pop)
///
/// The POP is baked into the Enhauto firmware as the ASCII string
/// `s3xy_enh` - a fixed vendor secret, same on every Commander ever made.
final class Security1 {
    static let deviceTypePHONE: Int32 = 1

    private let pop: Data
    private var priv: Curve25519.KeyAgreement.PrivateKey!
    private var ctr: AES_CTR?
    private(set) var clientPub = Data()
    private(set) var deviceVerifyExpected = Data()

    init(pop: String) { self.pop = Data(pop.utf8) }

    func makeStep0Request(disablePushEncryption: Bool) -> Data {
        priv = Curve25519.KeyAgreement.PrivateKey()
        // CryptoKit produces 32 bytes little-endian naturally - that's what
        // RFC 7748 (Curve25519) specifies for the wire. The Enhauto firmware
        // reads these via mbedtls_mpi_read_binary after a byte-swap, so from
        // the wire perspective we agree directly.
        clientPub = priv.publicKey.rawRepresentation
        let flags: UInt32 = disablePushEncryption ? SecFlags.DisablePushEncryption : SecFlags.AllIsEncrypted
        return Build.sessionData_sec1(Build.sec1_cmd0(clientPubkey: clientPub, flags: flags))
    }

    func makeStep1Request(fromDeviceStep0 data: Data) throws -> Data {
        let (msg, inner) = try Parse.sessionData(data)
        guard msg == Sec1Msg.Response0 else {
            throw CommanderError.handshakeFailed("expected Sec1 Response0, got msg=\(msg)")
        }
        let r0 = try Parse.sessionResp0(inner)
        guard let status = CommanderStatus(rawValue: r0.status), status == .success else {
            throw CommanderError.handshakeFailed("device returned status \(r0.status)")
        }
        guard r0.devicePubkey.count == 32 else { throw CommanderError.handshakeFailed("device_pubkey not 32 B") }
        guard r0.deviceRandom.count == 16 else { throw CommanderError.handshakeFailed("device_random not 16 B") }

        let devPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: r0.devicePubkey)
        let shared = try priv.sharedSecretFromKeyAgreement(with: devPub)
        var sharedBytes = Data(); shared.withUnsafeBytes { sharedBytes.append(contentsOf: $0) }

        let shaPop = Data(SHA256.hash(data: pop))        // 32 B
        var aesKey = Data(count: 32)
        for i in 0..<32 { aesKey[i] = sharedBytes[i] ^ shaPop[i] }

        ctr = AES_CTR(key: aesKey, iv: r0.deviceRandom)

        // client_verify_data = AES-CTR(device_pub)
        let clientVerify = ctr!.process(r0.devicePubkey)
        deviceVerifyExpected = clientPub   // we'll compare decrypted(device_verify_data) to this

        return Build.sessionData_sec1(
            Build.sec1_cmd1(clientVerifyData: clientVerify, deviceType: Security1.deviceTypePHONE)
        )
    }

    func verifyStep1(fromDeviceStep1 data: Data) throws {
        let (msg, inner) = try Parse.sessionData(data)
        guard msg == Sec1Msg.Response1 else {
            throw CommanderError.handshakeFailed("expected Sec1 Response1, got msg=\(msg)")
        }
        let r1 = try Parse.sessionResp1(inner)
        guard let status = CommanderStatus(rawValue: r1.status), status == .success else {
            throw CommanderError.handshakeFailed("device returned status \(r1.status)")
        }
        guard r1.deviceVerifyData.count == 32 else {
            throw CommanderError.handshakeFailed("device_verify_data not 32 B")
        }
        let got = ctr!.process(r1.deviceVerifyData)
        guard got == deviceVerifyExpected else {
            throw CommanderError.handshakeFailed("verify mismatch - wrong POP?")
        }
    }

    /// AES-CTR encrypt. Advances the session counter.
    func encrypt(_ plaintext: Data) -> Data { ctr!.process(plaintext) }

    /// AES-CTR decrypt (same op as encrypt in CTR mode). Advances the counter.
    func decrypt(_ ciphertext: Data) -> Data { ctr!.process(ciphertext) }
}

// MARK: - AES-CTR (CommonCrypto, since CryptoKit doesn't expose CTR)

final class AES_CTR {
    private var cryptor: CCCryptorRef?
    init(key: Data, iv: Data) {
        var cRef: CCCryptorRef?
        let status = key.withUnsafeBytes { k -> CCCryptorStatus in
            iv.withUnsafeBytes { i -> CCCryptorStatus in
                CCCryptorCreateWithMode(
                    CCOperation(kCCEncrypt), CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES), CCPadding(ccNoPadding),
                    i.baseAddress, k.baseAddress, k.count,
                    nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &cRef
                )
            }
        }
        precondition(status == kCCSuccess, "CCCryptorCreateWithMode failed: \(status)")
        cryptor = cRef
    }
    deinit { if let c = cryptor { CCCryptorRelease(c) } }
    func process(_ data: Data) -> Data {
        if data.isEmpty { return Data() }
        let n = data.count
        var out = Data(count: n); var moved = 0
        let s = data.withUnsafeBytes { ib in
            out.withUnsafeMutableBytes { ob in
                CCCryptorUpdate(cryptor, ib.baseAddress, n, ob.baseAddress, n, &moved)
            }
        }
        precondition(s == kCCSuccess)
        precondition(moved == n)
        return out
    }
}
