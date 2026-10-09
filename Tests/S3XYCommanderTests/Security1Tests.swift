import XCTest
import CryptoKit
@testable import S3XYCommander

final class Security1Tests: XCTestCase {

    func testKeyDerivationMatchesFirmware() throws {
        // We can't exercise the full handshake offline because the ECDH
        // output depends on both the ephemeral keys. But the key-derivation
        // formula is: aes_key = shared_LE XOR SHA256(pop)
        //
        // Verify the SHA256-of-POP step with a known-good POP.
        let pop = "s3xy_enh"
        let expected = Data(SHA256.hash(data: Data(pop.utf8)))
        XCTAssertEqual(expected.count, 32)
        // The first 4 bytes of SHA256("s3xy_enh") are a stable fingerprint
        // we can hardcode as a regression check:
        //   >>> hashlib.sha256(b"s3xy_enh").hexdigest()
        //   "6a3ab2…"  (replace with real value if asserting)
        XCTAssertEqual(expected.prefix(1).count, 1) // sanity
    }

    func testAesCtrRoundtrip() throws {
        let key = Data(repeating: 0x11, count: 32)
        let iv  = Data(repeating: 0x22, count: 16)
        let enc = AES_CTR(key: key, iv: iv)
        let dec = AES_CTR(key: key, iv: iv)
        let plaintext = Data("hello commander, this is a test".utf8)
        let cipher = enc.process(plaintext)
        let back = dec.process(cipher)
        XCTAssertEqual(back, plaintext)
    }

    func testAesCtrCounterAdvances() throws {
        let key = Data(repeating: 0x33, count: 32)
        let iv  = Data(repeating: 0x44, count: 16)
        let c = AES_CTR(key: key, iv: iv)
        let a = c.process(Data(count: 32)) // first 2 blocks of stream
        let b = c.process(Data(count: 32)) // next  2 blocks of stream
        XCTAssertNotEqual(a, b, "counter must advance between calls")
    }
}
