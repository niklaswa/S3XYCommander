import Foundation

/// The steering wheel's two scroll wheels, from the Commander's vehicle events
/// (`PushVehicleEventsDataHolder`), once ``S3XYCommanderClient/subscribeSteeringWheelEvents()``
/// asked for them. Like ``VehicleData`` a push carries only what changed.
///
/// Seen in a Model 3 on 2026-10-19: pressing and tilting come as ``SwitchState``
/// `.on`, then `.off`; turning comes as the steps since the last push, then 0.
public struct SteeringWheelEvents: Sendable, Equatable {
    public init() {}

    public var leftDoublePress: Bool?
    public var leftPressed: SwitchState?
    /// Steps turned since the last push, up positive (1 to 3 at a time, then 0).
    public var leftScrollTicks: Int32?
    public var leftTiltLeft: SwitchState?
    public var leftTiltRight: SwitchState?
    public var rightDoublePress: Bool?
    public var rightPressed: SwitchState?
    /// Steps turned since the last push, up positive.
    public var rightScrollTicks: Int32?
    public var rightTiltLeft: SwitchState?
    public var rightTiltRight: SwitchState?
}

/// `SwitchState` in the descriptor.
public enum SwitchState: UInt32, Sendable { case notAvailable = 0, off = 1, on = 2, fault = 3 }

enum SteeringWheelEventsDecoder {
    /// Parse a PushVehicleEventsDataHolder payload. The ticks are `int32`, so a
    /// step down is a ten-byte varint, not zigzag.
    static func decode(_ data: Data) throws -> SteeringWheelEvents {
        var r = ProtoReader(data); var e = SteeringWheelEvents()
        func state(_ v: UInt64) -> SwitchState? { SwitchState(rawValue: UInt32(truncatingIfNeeded: v)) }
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            case (1, 0):  e.leftDoublePress = try r.readVarint() != 0
            case (2, 0):  e.leftPressed = state(try r.readVarint())
            case (3, 0):  e.leftScrollTicks = varintAsInt32(try r.readVarint())
            case (4, 0):  e.leftTiltLeft = state(try r.readVarint())
            case (5, 0):  e.leftTiltRight = state(try r.readVarint())
            case (6, 0):  e.rightDoublePress = try r.readVarint() != 0
            case (7, 0):  e.rightPressed = state(try r.readVarint())
            case (8, 0):  e.rightScrollTicks = varintAsInt32(try r.readVarint())
            case (9, 0):  e.rightTiltLeft = state(try r.readVarint())
            case (10, 0): e.rightTiltRight = state(try r.readVarint())
            default:      try r.skip(wire: t.wire)
            }
        }
        return e
    }
}
