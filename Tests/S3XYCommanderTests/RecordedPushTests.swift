import XCTest
@testable import S3XYCommander

/// Pushes recorded in a Model 3 on 2026-10-19 with Tools/CommanderProbe, parked, 16 °C outside:
/// what the scales and encodings in `VehicleData` were worked out from.
final class RecordedPushTests: XCTestCase {
    /// From the first push after subscribing, the fields the tests check: battery, trip, temperatures.
    private let full = "0810ca0128d801208002a33c900294069802811da002d416a802ce02c80242d802eb0fd00324f8064d8007df01"
    /// From a later push: pack voltage and current, the 16 V side, the high-voltage bus, gear.
    private let electrical = "0810ca0117e00199b002e8011f900401e804b218f0049206f804de3c"

    private func payload(_ hex: String) throws -> Data {
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return try XCTUnwrap(try Parse.push(Data(bytes)).payload)
    }

    func testBatteryEnergyAndRange() throws {
        let v = try VehicleDataDecoder.decode(payload(full))
        XCTAssertEqual(try XCTUnwrap(v.nominalFullPackNowKwh), 74.26, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(v.nominalFullPackNewKwh), 78.8, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(v.nominalRemainingKwh), 58.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(v.energyBufferKwh), 3.34, accuracy: 0.001)
        // The car's charge is the usable share — which is what pins the scales down.
        let usable = try XCTUnwrap(v.usableEnergyKwh) / (try XCTUnwrap(v.nominalFullPackNowKwh) - v.energyBufferKwh!)
        XCTAssertEqual(usable * 100, Double(try XCTUnwrap(v.socPercent)), accuracy: 0.5)
        XCTAssertEqual(v.rangeMiles, 223)
        XCTAssertEqual(try XCTUnwrap(v.rangeKm), 358.9, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(v.maxRegenPowerKw), 77.15, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(v.cellMaxVolts), 4.054, accuracy: 0.0001)
    }

    func testSignedValuesAreZigzag() throws {
        let full = try VehicleDataDecoder.decode(payload(full))
        XCTAssertEqual(full.outsideTempC, 16)
        XCTAssertEqual(full.cellMaxTempC, 33)
        XCTAssertEqual(full.tempFrontStatorC, 18)

        let v = try VehicleDataDecoder.decode(payload(electrical))
        XCTAssertEqual(v.batteryCurrent, -16)
        XCTAssertEqual(try XCTUnwrap(v.batteryVolts), 389.37, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(v.lowBusVolts), 15.61, accuracy: 0.001)
        // The high-voltage bus sits at the pack's voltage — only when read as zigzag.
        XCTAssertEqual(try XCTUnwrap(v.highBusVolts), 388.7, accuracy: 0.001)
        XCTAssertEqual(v.highBusVolts!, v.batteryVolts!, accuracy: 2)
        // Parked, the pack feeds the 16 V side.
        XCTAssertLessThan(try XCTUnwrap(v.batteryPowerKw), 0)
        XCTAssertEqual(v.gear, .park)
    }

    func testTheClockIsZigzagToo() throws {
        // The car's clock as it comes (sint64, field 123), at a made-up time.
        let v = try VehicleDataDecoder.decode(payload("0810ca0107d80780e4ad950d"))
        XCTAssertEqual(v.currentTime, ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
    }

    func testSteeringWheelEvents() throws {
        XCTAssertEqual(try SteeringWheelEventsDecoder.decode(payload("0813e201021803")).leftScrollTicks, 3)
        // int32, not zigzag: a step down is a ten-byte varint.
        XCTAssertEqual(try SteeringWheelEventsDecoder.decode(payload("0813e2010b40feffffffffffffffff01")).rightScrollTicks, -2)
        XCTAssertEqual(try SteeringWheelEventsDecoder.decode(payload("0813e201021002")).leftPressed, .on)
        XCTAssertEqual(try SteeringWheelEventsDecoder.decode(payload("0813e201021001")).leftPressed, .off)
        XCTAssertEqual(try SteeringWheelEventsDecoder.decode(payload("0813e201024802")).rightTiltLeft, .on)
    }
}
