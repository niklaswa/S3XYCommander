import Foundation

/// A one-shot action the Commander can emulate on the Tesla's CAN bus -
/// equivalent to a user pressing a steering-wheel/stalk/screen control.
///
/// Pass to ``S3XYCommanderClient/tryAction(_:switchType:states:)``.
public enum TeslaAction: UInt32, CaseIterable, Sendable {
    case devTest = 0
    case openGloveBox = 1
    case openFrunk = 2
    case openTrunk = 3
    case driveModeAccel = 4
    case driveModeRegen = 5
    case driveModeSteering = 6
    case foldMirrors = 7
    case chargePort = 8
    case mediaControl = 9
    case hazardLights = 10
    case parkBrake = 11
    case interiorLights = 12
    case seatBeltsWarning = 13
    case trackMode = 14
    case honkHorn = 15
    case voiceCommand = 16
    case mirrorsDip = 17
    case rearSeatHeatLeft = 18
    case rearSeatHeatRight = 19
    case rearSeatHeatCentral = 20
    case rearSeatHeatAll = 21
    case mirrorsDim = 22
    case steeringWheelHeat = 23
    case partyMode = 24
    case frontSeatHeatLeft = 25
    case frontSeatHeatRight = 26
    case hvacBlower = 27
    case hvacDefogDefrost = 28
    case autopilotStart = 29
    case cruiseControlStart = 30
    case autopilotExtended = 31
    case wiperMode = 32
    case lightsControl = 33
    case autopilotSpeedAdjust = 34
    case childUnlock = 35
    case plaidLightsControl = 36
    case thankYou = 37
    case backWindowHeater = 38
    case headlights = 39
    case openDoor = 40
    case hvacSecondRowState = 41
    case precondition_ = 42
    case screenTilt = 43
    case frontSeatVentLeft = 44
    case frontSeatVentRight = 45
    case stoppingMode = 46
    case wipersHeat = 47
    case recirc = 48
    case acDisable = 49
    case frontFogLights = 50
    case rearFogLights = 51
    case allFogLights = 52
    case unlockCar = 53
    case wipersWasher = 54
    case tractionControl = 55
    case speedControl = 56
    case gearShift = 57
    case simulatePark = 58
    case trackModeStability = 59
    case trackModeHandling = 60
    case autopilotMax = 61
    case cabinTemp = 62
    case driverMoveSeat = 63
    case passengerMoveSeat = 64
    case disableMotor = 65
    case bioweaponDefence = 66
    case keepClimateOn = 67
    case dogMode = 68
    case campMode = 69
    case hvacOn = 70
    case ventWindows = 71
    case ventLeft = 72
    case ventRight = 73
    case allSeatHeat = 74
    case cabinTempLeft = 75
    case cabinTempRight = 76
    case suspension = 77
    case setLeftSeatProfile = 78
    case restoreLeftSeatProfile = 79
    case setRightSeatProfile = 80
    case restoreRightSeatProfile = 81
    case rearViewCamera = 82
    case lightStripBrightness = 83
    case highBeamStrobe = 84
    case setPassengerEasyEntrySeatProfile = 85
    case restorePassengerEasyEntrySeatProfile = 86
    case dynamicBrakeLights = 87
    case followDistance = 88
    case handWash = 89
    case frontLeftWindow = 90
    case frontRightWindow = 91
    case rearLeftWindow = 92
    case rearRightWindow = 93
    case grok = 94
    case sentryMode = 95
    case rideHandling = 96
    case sounds = 97
    case leftSeatMassage = 98
    case rightSeatMassage = 99
}

/// How the Commander should emulate the action. ``toggle`` (single press) is
/// the common case; use ``delay(seconds:)`` to insert a hold time before the
/// action fires (e.g. for long-press emulation).
///
/// **Important:** the firmware rejects actions whose `switchStates` array
/// is empty with `Status.InvalidArgument`. Always pass at least one state;
/// ``S3XYCommanderClient/tryAction(_:switchType:states:)`` defaults to `[1]`.
public enum SwitchType: Sendable {
    /// Single press - the common case.
    case toggle
    /// Latched switch.
    case switchOnOff
    /// Combined toggle + switch.
    case toggleAndSwitch
    /// Insert a pre-action delay. Only full seconds 0–10 and 0.5 are supported
    /// by the firmware; everything else is rounded down.
    case delay(seconds: Double)

    var rawValue: UInt32 {
        switch self {
        case .toggle:          return 0
        case .switchOnOff:     return 1
        case .toggleAndSwitch: return 2
        case .delay(let s):
            if s < 0.75  { return 10 }                             // Delay_0s
            if s < 1.0   { return 21 }                             // Delay_05s
            let whole = min(10, max(1, Int(s)))                    // 1..10
            return UInt32(10 + whole)                              // 11..20
        }
    }
}

// MARK: - Internal: wire format for ReqTryAction

enum ActionBuild {
    // PressActionConfig field numbers (actions.proto):
    static let PAC_actionType   = 1
    static let PAC_switchType   = 2
    static let PAC_switchStates = 3
    // ReqTryAction (buttons.proto): `PressActionConfig onePressActionsConfig = 1;`
    static let RTA_config       = 1
    // ReqExecuteButtonOneClick (buttons.proto): `bytes mac = 1;`
    static let REB_mac          = 1
    // EnhApiPayloadHolder oneof slots:
    static let EP_pReqTryAction              = 39   // msgType 28
    static let EP_pReqExecuteButtonOneClick  = 57   // msgType 46

    static let MType_ReqTryAction:              UInt32 = 28
    static let MType_RespTryAction:             UInt32 = 29
    static let MType_ReqExecuteButtonOneClick:  UInt32 = 46
    static let MType_RespExecuteButtonOneClick: UInt32 = 47

    static func pressActionConfig(action: TeslaAction, switchType: SwitchType, states: [UInt32]) -> Data {
        var w = ProtoWriter()
        w.writeUInt32(PAC_actionType, action.rawValue)
        w.writeUInt32(PAC_switchType, switchType.rawValue)
        if !states.isEmpty {
            w.writePackedVarints(PAC_switchStates, states.map { UInt64($0) })
        }
        return w.data
    }

    static func tryAction(_ action: TeslaAction, switchType: SwitchType, states: [UInt32]) -> Data {
        let cfg = pressActionConfig(action: action, switchType: switchType, states: states)
        var inner = ProtoWriter()
        inner.writeMessage(RTA_config, cfg)
        var outer = ProtoWriter()
        outer.writeUInt32(F.EP_msgType, MType_ReqTryAction)
        outer.writeMessage(EP_pReqTryAction, inner.data)
        return outer.data
    }

    static func executeButtonOneClick(mac: Data) -> Data {
        var inner = ProtoWriter()
        inner.writeBytes(REB_mac, mac)
        var outer = ProtoWriter()
        outer.writeUInt32(F.EP_msgType, MType_ReqExecuteButtonOneClick)
        outer.writeMessage(EP_pReqExecuteButtonOneClick, inner.data)
        return outer.data
    }
}
