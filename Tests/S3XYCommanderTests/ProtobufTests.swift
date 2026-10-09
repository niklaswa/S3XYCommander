import XCTest
@testable import S3XYCommander

final class ProtobufTests: XCTestCase {

    func testVarintRoundtrip() throws {
        for v in [UInt64(0), 1, 127, 128, 16383, 16384, 1082, UInt64.max] {
            var w = ProtoWriter(); w.writeVarint(v)
            var r = ProtoReader(w.data)
            XCTAssertEqual(try r.readVarint(), v)
        }
    }

    func testTagEncoding() throws {
        // Field 135, wire 2 → tag varint = (135<<3)|2 = 1082 = 0xBA 0x08
        var w = ProtoWriter()
        w.writeBytes(135, Data([0x6A, 0x01, 0x3D]))  // mimic ReqSubscribeVehicleData payload
        XCTAssertEqual(w.data, Data([0xBA, 0x08, 0x03, 0x6A, 0x01, 0x3D]))
    }

    func testSendUUIDWireFormat() throws {
        // Known-good capture from a live Commander session:
        //   plain=0820 da02 28 0a26 {uuid in ascii, 38 bytes}
        let uuid = "{260ac2ce-a519-4f4f-b299-215c5c4b217a}"
        let got = Build.sendUUID(uuid)
        let expectedPrefix = Data([0x08, 0x20, 0xDA, 0x02, 0x28, 0x0A, 0x26])
        XCTAssertEqual(got.prefix(expectedPrefix.count), expectedPrefix)
        XCTAssertEqual(got.count, expectedPrefix.count + uuid.utf8.count)
    }

    func testStatusDecode() throws {
        // Example RespSendUUID with status=4 (InvalidArgument), SW 6.8.3:
        //   plain = 08 21 e2 02 08 08 04 10 08 18 06 20 03
        let data = Data([0x08, 0x21, 0xE2, 0x02, 0x08, 0x08, 0x04, 0x10, 0x08, 0x18, 0x06, 0x20, 0x03])
        let (msg, status) = try Parse.respStatus(data)
        XCTAssertEqual(msg, 33)
        XCTAssertEqual(status, .invalidArgument)
    }
}
