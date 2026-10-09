import Foundation

/// A snapshot of live vehicle data pushed by the Commander. Every field is
/// `Optional`: the Commander only sends fields whose value has *changed*
/// since the previous push, so for any given snapshot only a subset is
/// populated. Call ``merged(with:)`` or hold your own stateful accumulator
/// if you want a "current full state" view.
///
/// Field numbers correspond to the firmware's `PushVehicleDataHolder` oneof
/// slots, which in turn match the `SubscribeVehicleDataField` enum values.
public struct VehicleData: Sendable, Equatable {
    public init() {}

    // MARK: Driving state
    /// Vehicle speed in km/h.
    public var speedKmh: UInt32?
    /// Accelerator pedal position (percent).
    public var accelPedalPercent: UInt32?
    public var turnSignalLeft: TurnSignalStatus?
    public var turnSignalRight: TurnSignalStatus?
    public var brakePressed: Bool?
    /// Shifter position (0=P, 1=R, 2=N, 3=D).
    public var gear: Gear?
    public var regenLevel: UInt32?
    public var driftModeState: UInt32?
    public var trackModeState: UInt32?
    public var accelerationMode: UInt32?
    public var motorOnModeState: UInt32?
    public var tractionControl: UInt32?
    public var stoppingMode: UInt32?
    public var wiperSpeed: UInt32?

    // MARK: Trip
    /// Usable state-of-energy percent (0–100).
    public var socPercent: UInt32?
    /// Range remaining in km (or miles, depending on car's display units).
    public var range: UInt32?

    // MARK: BMS / battery
    public var batteryVoltage: UInt32?
    public var batteryCurrent: Int32?
    public var chargeStatus: UInt32?
    public var idealEnergyRemaining: UInt32?
    public var maxRegenPowerKw: UInt32?
    public var maxDischargePowerKw: UInt32?
    public var nominalFullPackNewKwhTimes10: UInt32?
    public var nominalFullPackNowKwhTimes10: UInt32?
    public var nominalRemainingKwhTimes10: UInt32?
    public var energyBufferKwhTimes10: UInt32?
    public var tempPtInletC: Int32?
    public var tempBatteryInletC: Int32?
    public var tempInletTargetC: Int32?
    public var cellMaxTempC: Int32?
    public var cellMinTempC: Int32?
    public var cellMaxVoltage: UInt32?
    public var cellMinVoltage: UInt32?
    public var acChargeTotal: UInt32?
    public var dcChargeTotal: UInt32?
    public var regenTotal: UInt32?
    public var dischargeTotal: UInt32?
    public var batteryHeatingState: UInt32?

    // MARK: Drivetrain
    public var frontTorque: Int32?
    public var frontPowerKw: Int32?
    public var rearTorque: Int32?
    public var rearPowerKw: Int32?
    public var rearRightTorque: Int32?
    public var rearRightPowerKw: Int32?
    public var trackModeStability: UInt32?
    public var trackModeHandling: UInt32?
    public var tempFrontStatorC: Int32?
    public var tempRearStatorC: Int32?
    public var invertersCount: UInt32?
    public var rideAndHandling: UInt32?

    // MARK: Charging
    public var chargingDcCurrent: Int32?
    public var chargingDcVoltage: Int32?
    public var lowBusVoltage: Int32?
    public var lowBusCurrent: Int32?
    public var highBusVoltage: Int32?

    // MARK: Lights
    public var lightsDrl: UInt32?
    public var lightsLowBeam: UInt32?
    public var lightsHighBeam: UInt32?
    public var lightsFogFront: UInt32?
    public var lightsFogRear: UInt32?
    public var lightsPark: UInt32?
    public var autoHighBeamEnabled: UInt32?
    public var autoLights: UInt32?

    // MARK: Climate
    public var climateFanSpeed: UInt32?
    public var climateBioweaponDefence: UInt32?
    public var climateKeeperMode: UInt32?
    public var climateHvacOn: UInt32?
    public var climateVentWindows: UInt32?
    public var climateHeatedSeatsFL: UInt32?
    public var climateHeatedSeatsFR: UInt32?
    public var climateHeatedSeatsRL: UInt32?
    public var climateHeatedSeatsRC: UInt32?
    public var climateHeatedSeatsRR: UInt32?
    public var climateDefogDefrost: UInt32?
    public var climateSteeringWheelHeater: UInt32?
    public var climateRearVentToggle: UInt32?
    public var climateRecirculationToggle: UInt32?
    public var climateAcToggle: UInt32?
    public var climateSeatCoolingFL: UInt32?
    public var climateSeatCoolingFR: UInt32?

    // MARK: Autopilot
    public var autopilotCurrentState: UInt32?
    public var autopilotBlindSpotRearLeft: BlindSpotState?
    public var autopilotBlindSpotRearRight: BlindSpotState?
    public var autopilotHandsOnState: UInt32?
    public var autopilotFollowDistance: UInt32?
    public var autopilotSpeedLimit: UInt32?

    // MARK: Doors / Latches
    public var doorFrontLeft: LatchStatus?
    public var doorFrontRight: LatchStatus?
    public var doorRearLeft: LatchStatus?
    public var doorRearRight: LatchStatus?
    public var frunk: LatchStatus?
    public var trunk: LatchStatus?
    public var carLocked: UInt32?
    public var childUnlockLeft: UInt32?
    public var childUnlockRight: UInt32?

    // MARK: Sensors
    public var outsideTempC: Int32?
    public var brakeTempFrontLeftC: Int32?
    public var brakeTempFrontRightC: Int32?
    public var brakeTempRearLeftC: Int32?
    public var brakeTempRearRightC: Int32?

    // MARK: Navigation
    public var navCarLatitude: Float?
    public var navCarLongitude: Float?
    public var navCarLocationName: String?
    public var navDestinationLatitude: Float?
    public var navDestinationLongitude: Float?
    public var navDestinationLocationName: String?
    public var navDistanceInMiles: Float?
    public var navMinutesToArrival: Float?
    public var navEnergyAtArrival: Float?
    public var navTrafficMinutesDelay: Float?

    // MARK: Media
    public var mediaPlaybackStatus: MediaPlaybackStatus?
    public var mediaNowPlayingSource: MediaSource?
    public var mediaNowPlayingArtist: String?
    public var mediaNowPlayingTitle: String?
    public var mediaNowPlayingAlbum: String?
    public var mediaNowPlayingStation: String?
    public var mediaNowPlayingSourceString: String?
    public var mediaA2dpSourceName: String?
    public var mediaNowPlayingDurationSec: Int32?
    public var mediaNowPlayingElapsedSec: Int32?
    public var mediaAudioVolume: UInt32?
    public var mediaAudioVolumeIncrement: UInt32?
    public var mediaAudioVolumeMax: UInt32?

    // MARK: Display
    public var displayBrightness: UInt32?
    public var displayState: UInt32?
    public var displayTheme: UInt32?

    // MARK: Misc
    public var driverOrPassengerPresent: Bool?
    public var handWashState: UInt32?
    public var currentTimeSeconds: Int64?

    // MARK: - Merge
    /// Overlay this snapshot onto `base`, returning a new snapshot where
    /// every field of `base` that is not present in `self` is preserved.
    /// Useful for accumulating a stateful "current full snapshot" over the
    /// delta stream the Commander pushes.
    public func merged(onto base: VehicleData) -> VehicleData {
        var m = base
        let mirror = Mirror(reflecting: self)
        // Simple reflection-based merge; `nil` means "unchanged" per protocol.
        // For a fast path, apply manually in your app if preferred.
        for child in mirror.children {
            if let label = child.label {
                // Only overwrite when the new value is non-nil.
                // (We can't easily set via Mirror; fall back to the hand-rolled merge below.)
                _ = label
            }
        }
        // Hand-rolled merge is faster and keeps us type-safe:
        if let v = speedKmh                  { m.speedKmh = v }
        if let v = accelPedalPercent         { m.accelPedalPercent = v }
        if let v = turnSignalLeft            { m.turnSignalLeft = v }
        if let v = turnSignalRight           { m.turnSignalRight = v }
        if let v = brakePressed              { m.brakePressed = v }
        if let v = gear                      { m.gear = v }
        if let v = regenLevel                { m.regenLevel = v }
        if let v = driftModeState            { m.driftModeState = v }
        if let v = trackModeState            { m.trackModeState = v }
        if let v = accelerationMode          { m.accelerationMode = v }
        if let v = motorOnModeState          { m.motorOnModeState = v }
        if let v = tractionControl           { m.tractionControl = v }
        if let v = stoppingMode              { m.stoppingMode = v }
        if let v = wiperSpeed                { m.wiperSpeed = v }
        if let v = socPercent                { m.socPercent = v }
        if let v = range                     { m.range = v }
        if let v = batteryVoltage            { m.batteryVoltage = v }
        if let v = batteryCurrent            { m.batteryCurrent = v }
        if let v = chargeStatus              { m.chargeStatus = v }
        if let v = idealEnergyRemaining      { m.idealEnergyRemaining = v }
        if let v = maxRegenPowerKw           { m.maxRegenPowerKw = v }
        if let v = maxDischargePowerKw       { m.maxDischargePowerKw = v }
        if let v = nominalFullPackNewKwhTimes10 { m.nominalFullPackNewKwhTimes10 = v }
        if let v = nominalFullPackNowKwhTimes10 { m.nominalFullPackNowKwhTimes10 = v }
        if let v = nominalRemainingKwhTimes10 { m.nominalRemainingKwhTimes10 = v }
        if let v = energyBufferKwhTimes10    { m.energyBufferKwhTimes10 = v }
        if let v = tempPtInletC              { m.tempPtInletC = v }
        if let v = tempBatteryInletC         { m.tempBatteryInletC = v }
        if let v = tempInletTargetC          { m.tempInletTargetC = v }
        if let v = cellMaxTempC              { m.cellMaxTempC = v }
        if let v = cellMinTempC              { m.cellMinTempC = v }
        if let v = cellMaxVoltage            { m.cellMaxVoltage = v }
        if let v = cellMinVoltage            { m.cellMinVoltage = v }
        if let v = acChargeTotal             { m.acChargeTotal = v }
        if let v = dcChargeTotal             { m.dcChargeTotal = v }
        if let v = regenTotal                { m.regenTotal = v }
        if let v = dischargeTotal            { m.dischargeTotal = v }
        if let v = batteryHeatingState       { m.batteryHeatingState = v }
        if let v = frontTorque               { m.frontTorque = v }
        if let v = frontPowerKw              { m.frontPowerKw = v }
        if let v = rearTorque                { m.rearTorque = v }
        if let v = rearPowerKw               { m.rearPowerKw = v }
        if let v = rearRightTorque           { m.rearRightTorque = v }
        if let v = rearRightPowerKw          { m.rearRightPowerKw = v }
        if let v = trackModeStability        { m.trackModeStability = v }
        if let v = trackModeHandling         { m.trackModeHandling = v }
        if let v = tempFrontStatorC          { m.tempFrontStatorC = v }
        if let v = tempRearStatorC           { m.tempRearStatorC = v }
        if let v = invertersCount            { m.invertersCount = v }
        if let v = rideAndHandling           { m.rideAndHandling = v }
        if let v = chargingDcCurrent         { m.chargingDcCurrent = v }
        if let v = chargingDcVoltage         { m.chargingDcVoltage = v }
        if let v = lowBusVoltage             { m.lowBusVoltage = v }
        if let v = lowBusCurrent             { m.lowBusCurrent = v }
        if let v = highBusVoltage            { m.highBusVoltage = v }
        if let v = lightsDrl                 { m.lightsDrl = v }
        if let v = lightsLowBeam             { m.lightsLowBeam = v }
        if let v = lightsHighBeam            { m.lightsHighBeam = v }
        if let v = lightsFogFront            { m.lightsFogFront = v }
        if let v = lightsFogRear             { m.lightsFogRear = v }
        if let v = lightsPark                { m.lightsPark = v }
        if let v = autoHighBeamEnabled       { m.autoHighBeamEnabled = v }
        if let v = autoLights                { m.autoLights = v }
        if let v = climateFanSpeed           { m.climateFanSpeed = v }
        if let v = climateBioweaponDefence   { m.climateBioweaponDefence = v }
        if let v = climateKeeperMode         { m.climateKeeperMode = v }
        if let v = climateHvacOn             { m.climateHvacOn = v }
        if let v = climateVentWindows        { m.climateVentWindows = v }
        if let v = climateHeatedSeatsFL      { m.climateHeatedSeatsFL = v }
        if let v = climateHeatedSeatsFR      { m.climateHeatedSeatsFR = v }
        if let v = climateHeatedSeatsRL      { m.climateHeatedSeatsRL = v }
        if let v = climateHeatedSeatsRC      { m.climateHeatedSeatsRC = v }
        if let v = climateHeatedSeatsRR      { m.climateHeatedSeatsRR = v }
        if let v = climateDefogDefrost       { m.climateDefogDefrost = v }
        if let v = climateSteeringWheelHeater{ m.climateSteeringWheelHeater = v }
        if let v = climateRearVentToggle     { m.climateRearVentToggle = v }
        if let v = climateRecirculationToggle{ m.climateRecirculationToggle = v }
        if let v = climateAcToggle           { m.climateAcToggle = v }
        if let v = climateSeatCoolingFL      { m.climateSeatCoolingFL = v }
        if let v = climateSeatCoolingFR      { m.climateSeatCoolingFR = v }
        if let v = autopilotCurrentState     { m.autopilotCurrentState = v }
        if let v = autopilotBlindSpotRearLeft  { m.autopilotBlindSpotRearLeft = v }
        if let v = autopilotBlindSpotRearRight { m.autopilotBlindSpotRearRight = v }
        if let v = autopilotHandsOnState     { m.autopilotHandsOnState = v }
        if let v = autopilotFollowDistance   { m.autopilotFollowDistance = v }
        if let v = autopilotSpeedLimit       { m.autopilotSpeedLimit = v }
        if let v = doorFrontLeft             { m.doorFrontLeft = v }
        if let v = doorFrontRight            { m.doorFrontRight = v }
        if let v = doorRearLeft              { m.doorRearLeft = v }
        if let v = doorRearRight             { m.doorRearRight = v }
        if let v = frunk                     { m.frunk = v }
        if let v = trunk                     { m.trunk = v }
        if let v = carLocked                 { m.carLocked = v }
        if let v = childUnlockLeft           { m.childUnlockLeft = v }
        if let v = childUnlockRight          { m.childUnlockRight = v }
        if let v = outsideTempC              { m.outsideTempC = v }
        if let v = brakeTempFrontLeftC       { m.brakeTempFrontLeftC = v }
        if let v = brakeTempFrontRightC      { m.brakeTempFrontRightC = v }
        if let v = brakeTempRearLeftC        { m.brakeTempRearLeftC = v }
        if let v = brakeTempRearRightC       { m.brakeTempRearRightC = v }
        if let v = navCarLatitude            { m.navCarLatitude = v }
        if let v = navCarLongitude           { m.navCarLongitude = v }
        if let v = navCarLocationName        { m.navCarLocationName = v }
        if let v = navDestinationLatitude    { m.navDestinationLatitude = v }
        if let v = navDestinationLongitude   { m.navDestinationLongitude = v }
        if let v = navDestinationLocationName{ m.navDestinationLocationName = v }
        if let v = navDistanceInMiles        { m.navDistanceInMiles = v }
        if let v = navMinutesToArrival       { m.navMinutesToArrival = v }
        if let v = navEnergyAtArrival        { m.navEnergyAtArrival = v }
        if let v = navTrafficMinutesDelay    { m.navTrafficMinutesDelay = v }
        if let v = mediaPlaybackStatus       { m.mediaPlaybackStatus = v }
        if let v = mediaNowPlayingSource     { m.mediaNowPlayingSource = v }
        if let v = mediaNowPlayingArtist     { m.mediaNowPlayingArtist = v }
        if let v = mediaNowPlayingTitle      { m.mediaNowPlayingTitle = v }
        if let v = mediaNowPlayingAlbum      { m.mediaNowPlayingAlbum = v }
        if let v = mediaNowPlayingStation    { m.mediaNowPlayingStation = v }
        if let v = mediaNowPlayingSourceString { m.mediaNowPlayingSourceString = v }
        if let v = mediaA2dpSourceName       { m.mediaA2dpSourceName = v }
        if let v = mediaNowPlayingDurationSec{ m.mediaNowPlayingDurationSec = v }
        if let v = mediaNowPlayingElapsedSec { m.mediaNowPlayingElapsedSec = v }
        if let v = mediaAudioVolume          { m.mediaAudioVolume = v }
        if let v = mediaAudioVolumeIncrement { m.mediaAudioVolumeIncrement = v }
        if let v = mediaAudioVolumeMax       { m.mediaAudioVolumeMax = v }
        if let v = displayBrightness         { m.displayBrightness = v }
        if let v = displayState              { m.displayState = v }
        if let v = displayTheme              { m.displayTheme = v }
        if let v = driverOrPassengerPresent  { m.driverOrPassengerPresent = v }
        if let v = handWashState             { m.handWashState = v }
        if let v = currentTimeSeconds        { m.currentTimeSeconds = v }
        return m
    }
}

// MARK: - Enum sidecars

public enum Gear: UInt32, Sendable { case park = 0, reverse = 1, neutral = 2, drive = 3 }
public enum TurnSignalStatus: UInt32, Sendable { case off = 0, on = 1 }
public enum BlindSpotState: UInt32, Sendable { case clear = 0, warning = 1 }
public enum LatchStatus: UInt32, Sendable { case closed = 0, open = 1, ajar = 2 }
public enum MediaPlaybackStatus: UInt32, Sendable { case stopped = 0, playing = 1, paused = 2 }
public enum MediaSource: UInt32, Sendable {
    case none = 0, am = 1, fm = 2, xm = 3, slacker = 5, localFiles = 6, iPod = 7
    case bluetooth = 8, auxIn = 9, dab = 10, rdio = 11, spotify = 12, usRadio = 13
    case euRadio = 14, mediaFile = 16, tuneIn = 17, stingray = 18, siriusXM = 19
    case tidal = 20, qqMusic = 21, qqMusic2 = 22, ximalaya = 23, onlineRadio = 24
    case onlineRadio2 = 25, netEaseMusic = 26, browser = 28, theater = 29, game = 30
    case tutorial = 31, toybox = 32, recentsFavorites = 33, homeApps = 34, search = 35
}

// MARK: - Push decoding

enum VehicleDataDecoder {
    /// Parse a PushVehicleDataHolder plaintext payload into a VehicleData snapshot.
    static func decode(_ data: Data) throws -> VehicleData {
        var r = ProtoReader(data); var v = VehicleData()
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            // Navigation
            case (1, 5):   v.navCarLatitude = Float(bitPattern: try readFixed32(&r))
            case (2, 5):   v.navCarLongitude = Float(bitPattern: try readFixed32(&r))
            case (3, 2):   v.navCarLocationName = String(data: try r.readBytes(), encoding: .utf8)
            case (4, 5):   v.navDestinationLatitude = Float(bitPattern: try readFixed32(&r))
            case (5, 5):   v.navDestinationLongitude = Float(bitPattern: try readFixed32(&r))
            case (6, 2):   v.navDestinationLocationName = String(data: try r.readBytes(), encoding: .utf8)
            case (7, 5):   v.navDistanceInMiles = Float(bitPattern: try readFixed32(&r))
            case (8, 5):   v.navMinutesToArrival = Float(bitPattern: try readFixed32(&r))
            case (9, 5):   v.navEnergyAtArrival = Float(bitPattern: try readFixed32(&r))
            case (10, 5):  v.navTrafficMinutesDelay = Float(bitPattern: try readFixed32(&r))
            // Media
            case (11, 0):  v.mediaPlaybackStatus = MediaPlaybackStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (12, 0):  v.mediaNowPlayingSource = MediaSource(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (13, 2):  v.mediaNowPlayingArtist = String(data: try r.readBytes(), encoding: .utf8)
            case (14, 2):  v.mediaNowPlayingTitle = String(data: try r.readBytes(), encoding: .utf8)
            case (15, 2):  v.mediaNowPlayingSourceString = String(data: try r.readBytes(), encoding: .utf8)
            case (16, 2):  v.mediaNowPlayingAlbum = String(data: try r.readBytes(), encoding: .utf8)
            case (17, 2):  v.mediaNowPlayingStation = String(data: try r.readBytes(), encoding: .utf8)
            case (18, 2):  v.mediaA2dpSourceName = String(data: try r.readBytes(), encoding: .utf8)
            case (19, 0):  v.mediaNowPlayingDurationSec = varintAsInt32(try r.readVarint())
            case (20, 0):  v.mediaNowPlayingElapsedSec = varintAsInt32(try r.readVarint())
            case (21, 0):  v.mediaAudioVolume = UInt32(truncatingIfNeeded: try r.readVarint())
            case (22, 0):  v.mediaAudioVolumeIncrement = UInt32(truncatingIfNeeded: try r.readVarint())
            case (23, 0):  v.mediaAudioVolumeMax = UInt32(truncatingIfNeeded: try r.readVarint())
            // Display
            case (24, 0):  v.displayBrightness = UInt32(truncatingIfNeeded: try r.readVarint())
            case (25, 0):  v.displayState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (26, 0):  v.displayTheme = UInt32(truncatingIfNeeded: try r.readVarint())
            case (27, 0):  v.outsideTempC = varintAsInt32(try r.readVarint())
            // BMS
            case (28, 0):  v.batteryVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (29, 0):  v.batteryCurrent = varintAsInt32(try r.readVarint())
            case (30, 0):  v.chargeStatus = UInt32(truncatingIfNeeded: try r.readVarint())
            case (31, 0):  v.idealEnergyRemaining = UInt32(truncatingIfNeeded: try r.readVarint())
            case (32, 0):  v.maxRegenPowerKw = UInt32(truncatingIfNeeded: try r.readVarint())
            case (33, 0):  v.maxDischargePowerKw = UInt32(truncatingIfNeeded: try r.readVarint())
            case (34, 0):  v.nominalFullPackNewKwhTimes10 = UInt32(truncatingIfNeeded: try r.readVarint())
            case (35, 0):  v.nominalFullPackNowKwhTimes10 = UInt32(truncatingIfNeeded: try r.readVarint())
            case (36, 0):  v.nominalRemainingKwhTimes10 = UInt32(truncatingIfNeeded: try r.readVarint())
            case (37, 0):  v.energyBufferKwhTimes10 = UInt32(truncatingIfNeeded: try r.readVarint())
            case (38, 0):  v.tempPtInletC = varintAsInt32(try r.readVarint())
            case (39, 0):  v.tempBatteryInletC = varintAsInt32(try r.readVarint())
            case (40, 0):  v.tempInletTargetC = varintAsInt32(try r.readVarint())
            case (41, 0):  v.cellMaxTempC = varintAsInt32(try r.readVarint())
            case (42, 0):  v.cellMinTempC = varintAsInt32(try r.readVarint())
            case (43, 0):  v.cellMaxVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (44, 0):  v.cellMinVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (45, 0):  v.acChargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (46, 0):  v.dcChargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (47, 0):  v.regenTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (48, 0):  v.dischargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (49, 0):  v.batteryHeatingState = UInt32(truncatingIfNeeded: try r.readVarint())
            // Drivetrain
            case (50, 0):  v.frontTorque = varintAsInt32(try r.readVarint())
            case (51, 0):  v.frontPowerKw = varintAsInt32(try r.readVarint())
            case (52, 0):  v.rearTorque = varintAsInt32(try r.readVarint())
            case (53, 0):  v.rearPowerKw = varintAsInt32(try r.readVarint())
            case (54, 0):  v.rearRightTorque = varintAsInt32(try r.readVarint())
            case (55, 0):  v.rearRightPowerKw = varintAsInt32(try r.readVarint())
            case (56, 0):  v.trackModeStability = UInt32(truncatingIfNeeded: try r.readVarint())
            case (57, 0):  v.trackModeHandling = UInt32(truncatingIfNeeded: try r.readVarint())
            case (58, 0):  v.tempFrontStatorC = varintAsInt32(try r.readVarint())
            case (59, 0):  v.tempRearStatorC = varintAsInt32(try r.readVarint())
            case (60, 0):  v.invertersCount = UInt32(truncatingIfNeeded: try r.readVarint())
            // Driving state
            case (61, 0):  v.speedKmh = UInt32(truncatingIfNeeded: try r.readVarint())
            case (62, 0):  v.accelPedalPercent = UInt32(truncatingIfNeeded: try r.readVarint())
            case (63, 0):  v.turnSignalLeft = TurnSignalStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (64, 0):  v.turnSignalRight = TurnSignalStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (65, 0):  v.brakePressed = (try r.readVarint()) != 0
            case (66, 0):  v.gear = Gear(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (67, 0):  v.regenLevel = UInt32(truncatingIfNeeded: try r.readVarint())
            case (68, 0):  v.driftModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (69, 0):  v.trackModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (70, 0):  v.accelerationMode = UInt32(truncatingIfNeeded: try r.readVarint())
            case (71, 0):  v.motorOnModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (72, 0):  v.tractionControl = UInt32(truncatingIfNeeded: try r.readVarint())
            case (73, 0):  v.stoppingMode = UInt32(truncatingIfNeeded: try r.readVarint())
            case (74, 0):  v.wiperSpeed = UInt32(truncatingIfNeeded: try r.readVarint())
            // Charging
            case (75, 0):  v.chargingDcCurrent = varintAsInt32(try r.readVarint())
            case (76, 0):  v.chargingDcVoltage = varintAsInt32(try r.readVarint())
            case (77, 0):  v.lowBusVoltage = varintAsInt32(try r.readVarint())
            case (78, 0):  v.lowBusCurrent = varintAsInt32(try r.readVarint())
            case (79, 0):  v.highBusVoltage = varintAsInt32(try r.readVarint())
            // Lights
            case (80, 0):  v.lightsDrl = UInt32(truncatingIfNeeded: try r.readVarint())
            case (81, 0):  v.lightsLowBeam = UInt32(truncatingIfNeeded: try r.readVarint())
            case (82, 0):  v.lightsHighBeam = UInt32(truncatingIfNeeded: try r.readVarint())
            case (83, 0):  v.lightsFogFront = UInt32(truncatingIfNeeded: try r.readVarint())
            case (84, 0):  v.lightsFogRear = UInt32(truncatingIfNeeded: try r.readVarint())
            case (85, 0):  v.lightsPark = UInt32(truncatingIfNeeded: try r.readVarint())
            case (86, 0):  v.autoHighBeamEnabled = UInt32(truncatingIfNeeded: try r.readVarint())
            case (87, 0):  v.autoLights = UInt32(truncatingIfNeeded: try r.readVarint())
            // Climate
            case (88, 0):  v.climateFanSpeed = UInt32(truncatingIfNeeded: try r.readVarint())
            case (89, 0):  v.climateBioweaponDefence = UInt32(truncatingIfNeeded: try r.readVarint())
            case (90, 0):  v.climateKeeperMode = UInt32(truncatingIfNeeded: try r.readVarint())
            case (91, 0):  v.climateHvacOn = UInt32(truncatingIfNeeded: try r.readVarint())
            case (92, 0):  v.climateVentWindows = UInt32(truncatingIfNeeded: try r.readVarint())
            case (93, 0):  v.climateHeatedSeatsFL = UInt32(truncatingIfNeeded: try r.readVarint())
            case (94, 0):  v.climateHeatedSeatsFR = UInt32(truncatingIfNeeded: try r.readVarint())
            case (95, 0):  v.climateHeatedSeatsRL = UInt32(truncatingIfNeeded: try r.readVarint())
            case (96, 0):  v.climateHeatedSeatsRC = UInt32(truncatingIfNeeded: try r.readVarint())
            case (97, 0):  v.climateHeatedSeatsRR = UInt32(truncatingIfNeeded: try r.readVarint())
            case (98, 0):  v.climateDefogDefrost = UInt32(truncatingIfNeeded: try r.readVarint())
            case (99, 0):  v.climateSteeringWheelHeater = UInt32(truncatingIfNeeded: try r.readVarint())
            case (100, 0): v.climateRearVentToggle = UInt32(truncatingIfNeeded: try r.readVarint())
            case (101, 0): v.climateRecirculationToggle = UInt32(truncatingIfNeeded: try r.readVarint())
            case (102, 0): v.climateAcToggle = UInt32(truncatingIfNeeded: try r.readVarint())
            case (103, 0): v.climateSeatCoolingFL = UInt32(truncatingIfNeeded: try r.readVarint())
            case (104, 0): v.climateSeatCoolingFR = UInt32(truncatingIfNeeded: try r.readVarint())
            // Autopilot
            case (105, 0): v.autopilotCurrentState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (106, 0): v.autopilotBlindSpotRearLeft = BlindSpotState(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (107, 0): v.autopilotBlindSpotRearRight = BlindSpotState(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (108, 0): v.autopilotHandsOnState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (109, 0): v.autopilotFollowDistance = UInt32(truncatingIfNeeded: try r.readVarint())
            case (110, 0): v.autopilotSpeedLimit = UInt32(truncatingIfNeeded: try r.readVarint())
            // Trip
            case (111, 0): v.socPercent = UInt32(truncatingIfNeeded: try r.readVarint())
            case (112, 0): v.range = UInt32(truncatingIfNeeded: try r.readVarint())
            // Doors
            case (113, 0): v.doorFrontLeft = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (114, 0): v.doorFrontRight = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (115, 0): v.doorRearLeft = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (116, 0): v.doorRearRight = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (117, 0): v.frunk = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (118, 0): v.trunk = LatchStatus(rawValue: UInt32(truncatingIfNeeded: try r.readVarint()))
            case (119, 0): v.carLocked = UInt32(truncatingIfNeeded: try r.readVarint())
            case (120, 0): v.childUnlockLeft = UInt32(truncatingIfNeeded: try r.readVarint())
            case (121, 0): v.childUnlockRight = UInt32(truncatingIfNeeded: try r.readVarint())
            // Misc
            case (122, 0): v.handWashState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (123, 0): v.currentTimeSeconds = Int64(bitPattern: try r.readVarint())
            case (124, 0): v.rideAndHandling = UInt32(truncatingIfNeeded: try r.readVarint())
            case (125, 0): v.brakeTempFrontLeftC = varintAsInt32(try r.readVarint())
            case (126, 0): v.brakeTempFrontRightC = varintAsInt32(try r.readVarint())
            case (127, 0): v.brakeTempRearLeftC = varintAsInt32(try r.readVarint())
            case (128, 0): v.brakeTempRearRightC = varintAsInt32(try r.readVarint())
            case (129, 0): v.driverOrPassengerPresent = (try r.readVarint()) != 0
            default:
                try r.skip(wire: t.wire)
            }
        }
        return v
    }

    @inline(__always)
    private static func readFixed32(_ r: inout ProtoReader) throws -> UInt32 {
        try r.readFixed32()
    }
}
