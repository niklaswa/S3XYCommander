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
        // Fields: gear=4 (D in DI_gear), trip_data_usoe=72, trip_data_range=314
        // gear:  (66<<3)|0 = 528 = 0x90 0x04        → 90 04 04
        // soc:   (111<<3)|0 = 888 = 0xF8 0x06       → F8 06 48
        // range: (112<<3)|0 = 896 = 0x80 0x07       → 80 07 BA 02  (314 = 0xBA 0x02)
        let data = Data([0x90, 0x04, 0x04, 0xF8, 0x06, 0x48, 0x80, 0x07, 0xBA, 0x02])
        let v = try VehicleDataDecoder.decode(data)
        XCTAssertEqual(v.gear, .drive)
        XCTAssertEqual(v.gearRaw, 4)
        XCTAssertEqual(v.socPercent, 72)
        XCTAssertEqual(v.range, 314)
    }

    func testGearFollowsDIGear() throws {
        let expected: [UInt32: Gear] = [1: .park, 2: .reverse, 3: .neutral, 4: .drive]
        for (raw, gear) in expected {
            let v = try decode([(66, raw)])
            XCTAssertEqual(v.gear, gear, "raw \(raw)")
            XCTAssertEqual(v.gearRaw, raw)
        }
    }

    func testUnknownGearKeepsRawValue() throws {
        // 0 is DI_GEAR_INVALID, 7 DI_GEAR_SNA, 9 is not defined at all.
        for raw: UInt32 in [0, 7, 9] {
            let v = try decode([(66, raw)])
            XCTAssertNil(v.gear, "raw \(raw)")
            XCTAssertEqual(v.gearRaw, raw)
        }
    }

    func testEnumFieldsKeepRawValues() throws {
        let v = try decode([
            (63, 2),    // turn signal left: active high
            (64, 0),    // turn signal right: off
            (106, 2),   // blind spot rear left: warning level 2
            (107, 3),   // blind spot rear right: SNA
            (113, 2),   // front left door: closed
            (114, 5),   // front right door: ajar
            (115, 8),   // rear left door: fault
            (117, 3),   // frunk: closing
            (11, 3),    // playback status: not in the descriptor
            (12, 4),    // media source: gap in MediaSourceType
        ])
        XCTAssertEqual(v.turnSignalLeft, .on)
        XCTAssertEqual(v.turnSignalLeftRaw, 2)
        XCTAssertEqual(v.turnSignalRight, .off)
        XCTAssertEqual(v.turnSignalRightRaw, 0)
        XCTAssertEqual(v.autopilotBlindSpotRearLeft, .warning)
        XCTAssertEqual(v.autopilotBlindSpotRearLeftRaw, 2)
        XCTAssertNil(v.autopilotBlindSpotRearRight)
        XCTAssertEqual(v.autopilotBlindSpotRearRightRaw, 3)
        XCTAssertEqual(v.doorFrontLeft, .closed)
        XCTAssertEqual(v.doorFrontLeftRaw, 2)
        XCTAssertEqual(v.doorFrontRight, .ajar)
        XCTAssertEqual(v.doorFrontRightRaw, 5)
        XCTAssertNil(v.doorRearLeft)
        XCTAssertEqual(v.doorRearLeftRaw, 8)
        XCTAssertEqual(v.frunk, .open)
        XCTAssertEqual(v.frunkRaw, 3)
        XCTAssertNil(v.mediaPlaybackStatus)
        XCTAssertEqual(v.mediaPlaybackStatusRaw, 3)
        XCTAssertNil(v.mediaNowPlayingSource)
        XCTAssertEqual(v.mediaNowPlayingSourceRaw, 4)
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

    func testMergeCarriesRawFields() throws {
        let base = try decode([(66, 1), (63, 0), (113, 2), (12, 12)])
        let delta = try decode([(66, 4), (63, 1), (118, 1), (11, 1)])
        let merged = delta.merged(onto: base)
        XCTAssertEqual(merged.gear, .drive)
        XCTAssertEqual(merged.gearRaw, 4)
        XCTAssertEqual(merged.turnSignalLeft, .on)
        XCTAssertEqual(merged.turnSignalLeftRaw, 1)
        XCTAssertEqual(merged.trunk, .open)
        XCTAssertEqual(merged.trunkRaw, 1)
        XCTAssertEqual(merged.mediaPlaybackStatusRaw, 1)
        // Not in the delta: kept from the base, raw value included.
        XCTAssertEqual(merged.doorFrontLeft, .closed)
        XCTAssertEqual(merged.doorFrontLeftRaw, 2)
        XCTAssertEqual(merged.mediaNowPlayingSource, .spotify)
        XCTAssertEqual(merged.mediaNowPlayingSourceRaw, 12)
    }

    func testMergeUnknownValueClearsStaleCase() throws {
        // The old decoder dropped values without a case and the merge kept the
        // previous gear on screen; an unknown number must replace it instead.
        let base = try decode([(66, 2)])
        let delta = try decode([(66, 7)])
        let merged = delta.merged(onto: base)
        XCTAssertNil(merged.gear)
        XCTAssertEqual(merged.gearRaw, 7)
    }

    func testBrakePressedBool() throws {
        // Field 65, varint 1 → true
        let data = Data([0x88, 0x04, 0x01])
        let v = try VehicleDataDecoder.decode(data)
        XCTAssertEqual(v.brakePressed, true)
    }

    /// Decode a push carrying the given varint fields.
    private func decode(_ fields: [(Int, UInt32)]) throws -> VehicleData {
        var w = ProtoWriter()
        for (field, value) in fields { w.writeUInt32(field, value) }
        return try VehicleDataDecoder.decode(w.data)
    }
}
