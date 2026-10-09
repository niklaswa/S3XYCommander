import XCTest
@testable import S3XYCommander

final class VehicleDataTests: XCTestCase {

    func testDecodeSpeed() throws {
        // PushVehicleDataHolder with driving_state_speed = 85 (field 61).
        // Tag: (61<<3)|0 = 488 = 0xE8 0x03.  Value: 85 = 0x55.
        let data = Data([0xE8, 0x03, 0x55])
        let v = try VehicleDataDecoder.decode(data)
        XCTAssertEqual(v.speedKmh, 85)
    }

    func testDecodeGearAndSocCombo() throws {
        // Fields: gear=3 (D), trip_data_usoe=72, trip_data_range=314
        // gear:  (66<<3)|0 = 528 = 0x90 0x04        → 90 04 03
        // soc:   (111<<3)|0 = 888 = 0xF8 0x06       → F8 06 48
        // range: (112<<3)|0 = 896 = 0x80 0x07       → 80 07 BA 02  (314 = 0xBA 0x02)
        let data = Data([0x90, 0x04, 0x03, 0xF8, 0x06, 0x48, 0x80, 0x07, 0xBA, 0x02])
        let v = try VehicleDataDecoder.decode(data)
        XCTAssertEqual(v.gear, .drive)
        XCTAssertEqual(v.socPercent, 72)
        XCTAssertEqual(v.range, 314)
    }

    func testMergeKeepsPreviousWhereNil() throws {
        var base = VehicleData()
        base.speedKmh = 50
        base.socPercent = 80
        var delta = VehicleData()
        delta.speedKmh = 55                   // overrides
        delta.gear = .drive                   // adds
        let merged = delta.merged(onto: base)
        XCTAssertEqual(merged.speedKmh, 55)
        XCTAssertEqual(merged.socPercent, 80) // preserved
        XCTAssertEqual(merged.gear, .drive)
    }

    func testBrakePressedBool() throws {
        // Field 65, varint 1 → true
        let data = Data([0x88, 0x04, 0x01])
        let v = try VehicleDataDecoder.decode(data)
        XCTAssertEqual(v.brakePressed, true)
    }
}
