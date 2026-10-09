import Foundation

/// All subscribable signals the Commander exposes. Enum values match the
/// firmware's `SubscribeVehicleDataField` enum exactly, so passing these to
/// ``S3XYCommanderClient/subscribeAll(fields:)`` goes on the wire 1:1.
///
/// For a full dump including firmware-side units, see README §Signals.
public enum VehicleSignal: UInt64, CaseIterable, Sendable {
    // Navigation
    case navCarLatitude = 1
    case navCarLongitude = 2
    case navCarLocationName = 3
    case navDestinationLatitude = 4
    case navDestinationLongitude = 5
    case navDestinationLocationName = 6
    case navDistanceInMiles = 7
    case navMinutesToArrival = 8
    case navEnergyAtArrival = 9
    case navTrafficMinutesDelay = 10

    // Media
    case mediaPlaybackStatus = 11
    case mediaNowPlayingSource = 12
    case mediaNowPlayingArtist = 13
    case mediaNowPlayingTitle = 14
    case mediaNowPlayingSourceString = 15
    case mediaNowPlayingAlbum = 16
    case mediaNowPlayingStation = 17
    case mediaA2dpSourceName = 18
    case mediaNowPlayingDuration = 19
    case mediaNowPlayingElapsed = 20
    case mediaAudioVolume = 21
    case mediaAudioVolumeIncrement = 22
    case mediaAudioVolumeMax = 23

    // Display + outside temp
    case displayBrightness = 24
    case displayState = 25
    case displayTheme = 26
    case outsideTemperature = 27

    // BMS / battery
    case bmsBatteryVoltage = 28
    case bmsBatteryCurrent = 29
    case bmsChargeStatus = 30
    case bmsIdealEnergyRemaining = 31
    case bmsMaxRegenPower = 32
    case bmsMaxDischargePower = 33
    case bmsNominalFullPackNew = 34
    case bmsNominalFullPackNow = 35
    case bmsNominalRemaining = 36
    case bmsEnergyBuffer = 37
    case bmsTempPtInlet = 38
    case bmsTempBatteryInlet = 39
    case bmsTempInletTarget = 40
    case bmsCellMaxTemp = 41
    case bmsCellMinTemp = 42
    case bmsCellMaxVoltage = 43
    case bmsCellMinVoltage = 44
    case bmsAcChargeTotal = 45
    case bmsDcChargeTotal = 46
    case bmsRegenTotal = 47
    case bmsDischargeTotal = 48
    case bmsBatteryHeatingState = 49

    // Drivetrain
    case drivetrainFrontTorque = 50
    case drivetrainFrontPower = 51
    case drivetrainRearTorque = 52
    case drivetrainRearPower = 53
    case drivetrainRearRightTorque = 54
    case drivetrainRearRightPower = 55
    case drivetrainTrackModeStability = 56
    case drivetrainTrackModeHandling = 57
    case drivetrainTempFrontStator = 58
    case drivetrainTempRearStator = 59
    case drivetrainInvertersCount = 60

    // Driving state
    case drivingStateSpeed = 61
    case drivingStateAccelPedalPos = 62
    case drivingStateTurnSignalLeft = 63
    case drivingStateTurnSignalRight = 64
    case drivingStateBrakePressed = 65
    case drivingStateGear = 66
    case drivingStateRegenLevel = 67
    case drivingStateDriftModeState = 68
    case drivingStateTrackModeState = 69
    case drivingStateAccelerationMode = 70
    case drivingStateMotorOnModeState = 71
    case drivingStateTractionControl = 72
    case drivingStateStoppingMode = 73
    case drivingStateWiperSpeed = 74

    // Charging
    case chargingDcCurrent = 75
    case chargingDcVoltage = 76
    case chargingLowBusVoltage = 77
    case chargingLowBusCurrent = 78
    case chargingHighBusVoltage = 79

    // Lights
    case lightsDrl = 80
    case lightsLowBeam = 81
    case lightsHighBeam = 82
    case lightsFogFront = 83
    case lightsFogRear = 84
    case lightsPark = 85
    case lightsAutoHighBeamEnabled = 86
    case lightsAutoLights = 87

    // Climate
    case climateFanSpeed = 88
    case climateBioweaponDefence = 89
    case climateKeeperMode = 90
    case climateHvacOn = 91
    case climateVentWindows = 92
    case climateHeatedSeatsFl = 93
    case climateHeatedSeatsFr = 94
    case climateHeatedSeatsRl = 95
    case climateHeatedSeatsRc = 96
    case climateHeatedSeatsRr = 97
    case climateDefogDefrost = 98
    case climateSteeringWheelHeater = 99
    case climateRearVentToggle = 100
    case climateRecirculationToggle = 101
    case climateAcToggle = 102
    case climateSeatCoolingFl = 103
    case climateSeatCoolingFr = 104

    // Autopilot
    case autopilotCurrentState = 105
    case autopilotBlindSpotRearLeft = 106
    case autopilotBlindSpotRearRight = 107
    case autopilotHandsOnState = 108
    case autopilotFollowDistance = 109
    case autopilotSpeedLimit = 110

    // Trip
    case tripDataUsoe = 111
    case tripDataRange = 112

    // Doors / Latches
    case latchFrontLeftDoor = 113
    case latchFrontRightDoor = 114
    case latchRearLeftDoor = 115
    case latchRearRightDoor = 116
    case latchFrunk = 117
    case latchTrunk = 118
    case latchCarLocked = 119
    case latchChildUnlockLeft = 120
    case latchChildUnlockRight = 121

    // Misc
    case othersHandWashState = 122
    case othersCurrentTimeInSeconds = 123
    case drivetrainRideAndHandling = 124
    case sensorsFrontLeftBrakeTemp = 125
    case sensorsFrontRightBrakeTemp = 126
    case sensorsRearLeftBrakeTemp = 127
    case sensorsRearRightBrakeTemp = 128
    case driverOrPassengerPresent = 129
}
