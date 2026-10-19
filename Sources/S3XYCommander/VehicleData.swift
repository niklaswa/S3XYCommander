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
    /// The number behind ``turnSignalLeft``, kept even when no case matches it.
    public var turnSignalLeftRaw: UInt32?
    public var turnSignalRight: TurnSignalStatus?
    /// The number behind ``turnSignalRight``, kept even when no case matches it.
    public var turnSignalRightRaw: UInt32?
    public var brakePressed: Bool?
    /// Shifter position. See ``Gear`` for how sure the mapping is.
    public var gear: Gear?
    /// The number the Commander sent for the gear, kept even when ``Gear``
    /// has no case for it.
    public var gearRaw: UInt32?
    public var regenLevel: UInt32?
    public var driftModeState: UInt32?
    public var trackModeState: UInt32?
    public var accelerationMode: UInt32?
    public var motorOnModeState: UInt32?
    public var tractionControl: UInt32?
    public var stoppingMode: UInt32?
    public var wiperSpeed: UInt32?

    // MARK: Trip
    /// Usable state of energy, % (0–100): the charge the car shows. It is
    /// (``nominalRemaining`` − ``energyBuffer``) / (``nominalFullPackNow`` − ``energyBuffer``).
    public var socPercent: UInt32?
    /// Range in miles, whatever the car displays: 223 at 77 % on a 74 kWh pack,
    /// and it disagreed with the car's km. ``rangeKm`` converts it.
    public var rangeMiles: UInt32?

    // MARK: BMS / battery
    // Scales worked out in a Model 3 on 2026-10-19 (README, "Units"); the
    // extension "In units" below converts them.
    /// Pack voltage, 0.01 V (38930 = 389.30 V).
    public var batteryVoltage: UInt32?
    /// Pack current, 0.1 A, negative while the pack gives energy (parked: −14,
    /// −1.4 A, which at the pack's voltage is what the 12 V side drew).
    public var batteryCurrent: Int32?
    public var chargeStatus: UInt32?
    /// Ideal energy left, 0.02 kWh (2888 = 57.76 kWh).
    public var idealEnergyRemaining: UInt32?
    /// The most the pack takes while regenerating, 0.01 kW (7715 = 77.15 kW).
    public var maxRegenPower: UInt32?
    /// The most the pack gives, 0.01 kW (28838 = 288.38 kW).
    public var maxDischargePower: UInt32?
    /// Pack energy when new, 0.1 kWh (788 = 78.8 kWh).
    public var nominalFullPackNew: UInt32?
    /// Pack energy when full, now, 0.02 kWh (3713 = 74.26 kWh).
    public var nominalFullPackNow: UInt32?
    /// Energy left, 0.02 kWh (2900 = 58.0 kWh).
    public var nominalRemaining: UInt32?
    /// Energy held back below 0 %, 0.01 kWh (334 = 3.34 kWh).
    public var energyBuffer: UInt32?
    /// Coolant at the powertrain and battery inlets, and the inlet target.
    /// Unit not confirmed: parked with the cells at 33 °C they read 131, 127
    /// and 120 — 0.1 °C or 0.25 °C.
    public var tempPtInlet: Int32?
    public var tempBatteryInlet: Int32?
    public var tempInletTarget: Int32?
    /// Warmest and coldest cell, °C (33 and 32 parked after a drive; plausible,
    /// not cross-checked).
    public var cellMaxTempC: Int32?
    public var cellMinTempC: Int32?
    /// Highest and lowest cell voltage, 0.002 V (2027 = 4.054 V at 78 %).
    public var cellMaxVoltage: UInt32?
    public var cellMinVoltage: UInt32?
    /// Lifetime energy, Wh: charged over AC and DC, regenerated, given by the pack.
    public var acChargeTotal: UInt32?
    public var dcChargeTotal: UInt32?
    public var regenTotal: UInt32?
    public var dischargeTotal: UInt32?
    public var batteryHeatingState: UInt32?

    // MARK: Drivetrain
    // Torque and power: 0 parked; their scale is still to be seen while driving.
    public var frontTorque: Int32?
    public var frontPowerKw: Int32?
    public var rearTorque: Int32?
    public var rearPowerKw: Int32?
    public var rearRightTorque: Int32?
    public var rearRightPowerKw: Int32?
    public var trackModeStability: UInt32?
    public var trackModeHandling: UInt32?
    /// Stator temperatures, °C (18 and 17 parked, the air at 16 °C).
    public var tempFrontStatorC: Int32?
    public var tempRearStatorC: Int32?
    public var invertersCount: UInt32?
    public var rideAndHandling: UInt32?

    // MARK: Charging
    /// DC fast charging; scale still to be seen at a charger (14 parked, not charging).
    public var chargingDcCurrent: Int32?
    public var chargingDcVoltage: Int32?
    /// The low-voltage (16 V) side, 0.01 V (1556 = 15.56 V).
    public var lowBusVoltage: Int32?
    /// The low-voltage side's current, 0.1 A (304 = 30.4 A).
    public var lowBusCurrent: Int32?
    /// The high-voltage bus, 0.1 V (3886 = 388.6 V, next to the pack's 389.25 V).
    public var highBusVoltage: Int32?

    // MARK: Lights
    // 0 off, 17 on for daytime, low, high beam and parking lights: one bit per
    // side, it seems (0x01, 0x10) — the single rear fog lamp reads 1.
    public var lightsDrl: UInt32?
    public var lightsLowBeam: UInt32?
    public var lightsHighBeam: UInt32?
    public var lightsFogFront: UInt32?
    public var lightsFogRear: UInt32?
    public var lightsPark: UInt32?
    public var autoHighBeamEnabled: UInt32?
    /// The light switch, `LightSwitchStatus`: 0 auto, 1 on, 3 off (2, parking
    /// lights, not seen).
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
    /// A bare `uint32` in the descriptor (see the enum sidecars below), encoding
    /// not confirmed. Candidates: Tesla's DAS_autopilotState (3 active,
    /// 4 restricted, 5 Navigate on Autopilot) or Enhauto's own `CurrApState`.
    public var autopilotCurrentState: UInt32?
    public var autopilotBlindSpotRearLeft: BlindSpotState?
    /// The number behind ``autopilotBlindSpotRearLeft``, kept even when no case matches it.
    public var autopilotBlindSpotRearLeftRaw: UInt32?
    public var autopilotBlindSpotRearRight: BlindSpotState?
    /// The number behind ``autopilotBlindSpotRearRight``, kept even when no case matches it.
    public var autopilotBlindSpotRearRightRaw: UInt32?
    /// `AutopilotHandsOnState` in the descriptor: 0 not required, 1 required
    /// and detected, 2 required but not detected, 3 visual warning, 4/5 chime,
    /// 6 slowing, 7 struck out, 8 suspended, 9/10 escalated chime, 15 SNA.
    /// Parked it goes between 2 and 1 as a hand turns the wheel's rollers.
    public var autopilotHandsOnState: UInt32?
    public var autopilotFollowDistance: UInt32?
    /// The speed limit the car knows, in its display units (30 in a 30 km/h street).
    public var autopilotSpeedLimit: UInt32?

    // MARK: Doors / Latches
    public var doorFrontLeft: LatchStatus?
    /// The number behind ``doorFrontLeft``, kept even when no case matches it.
    public var doorFrontLeftRaw: UInt32?
    public var doorFrontRight: LatchStatus?
    /// The number behind ``doorFrontRight``, kept even when no case matches it.
    public var doorFrontRightRaw: UInt32?
    public var doorRearLeft: LatchStatus?
    /// The number behind ``doorRearLeft``, kept even when no case matches it.
    public var doorRearLeftRaw: UInt32?
    public var doorRearRight: LatchStatus?
    /// The number behind ``doorRearRight``, kept even when no case matches it.
    public var doorRearRightRaw: UInt32?
    public var frunk: LatchStatus?
    /// The number behind ``frunk``, kept even when no case matches it.
    public var frunkRaw: UInt32?
    public var trunk: LatchStatus?
    /// The number behind ``trunk``, kept even when no case matches it.
    public var trunkRaw: UInt32?
    /// 1 locked, 0 unlocked.
    public var carLocked: UInt32?
    public var childUnlockLeft: UInt32?
    public var childUnlockRight: UInt32?

    // MARK: Sensors
    /// Outside air, °C.
    public var outsideTempC: Int32?
    /// The car's brake temperature estimates. Unit not confirmed: parked they
    /// read 6 to 11 and rose, with the air at 16 °C.
    public var brakeTempFrontLeft: Int32?
    public var brakeTempFrontRight: Int32?
    public var brakeTempRearLeft: Int32?
    public var brakeTempRearRight: Int32?

    // MARK: Navigation
    // From the car's API, which the Commander reaches as a paired key (Enhauto's
    // "Tesla API" add-on); without it these stay empty. The car's own position
    // came as 0, 0 while its location name came.
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
    /// The number behind ``mediaPlaybackStatus``, kept even when no case matches it.
    public var mediaPlaybackStatusRaw: UInt32?
    public var mediaNowPlayingSource: MediaSource?
    /// The number behind ``mediaNowPlayingSource``, kept even when no case matches it.
    public var mediaNowPlayingSourceRaw: UInt32?
    public var mediaNowPlayingArtist: String?
    public var mediaNowPlayingTitle: String?
    public var mediaNowPlayingAlbum: String?
    public var mediaNowPlayingStation: String?
    public var mediaNowPlayingSourceString: String?
    public var mediaA2dpSourceName: String?
    /// Duration, elapsed time and volume: the Commander sent 0 or nothing, with
    /// Spotify and DAB radio playing and the volume turned (2026-10-19).
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
    /// The car's clock, seconds since 1970. ``currentTime`` as a `Date`.
    public var currentTimeSeconds: Int64?

    // MARK: - Merge
    /// Overlay this snapshot onto `base`, returning a new snapshot where
    /// every field of `base` that is not present in `self` is preserved.
    /// Useful for accumulating a stateful "current full snapshot" over the
    /// delta stream the Commander pushes.
    public func merged(onto base: VehicleData) -> VehicleData {
        var m = base
        // `nil` means "unchanged" per protocol.
        if let v = speedKmh                  { m.speedKmh = v }
        if let v = accelPedalPercent         { m.accelPedalPercent = v }
        Self.merge(turnSignalLeft, turnSignalLeftRaw, into: &m.turnSignalLeft, &m.turnSignalLeftRaw)
        Self.merge(turnSignalRight, turnSignalRightRaw, into: &m.turnSignalRight, &m.turnSignalRightRaw)
        if let v = brakePressed              { m.brakePressed = v }
        Self.merge(gear, gearRaw, into: &m.gear, &m.gearRaw)
        if let v = regenLevel                { m.regenLevel = v }
        if let v = driftModeState            { m.driftModeState = v }
        if let v = trackModeState            { m.trackModeState = v }
        if let v = accelerationMode          { m.accelerationMode = v }
        if let v = motorOnModeState          { m.motorOnModeState = v }
        if let v = tractionControl           { m.tractionControl = v }
        if let v = stoppingMode              { m.stoppingMode = v }
        if let v = wiperSpeed                { m.wiperSpeed = v }
        if let v = socPercent                { m.socPercent = v }
        if let v = rangeMiles                { m.rangeMiles = v }
        if let v = batteryVoltage            { m.batteryVoltage = v }
        if let v = batteryCurrent            { m.batteryCurrent = v }
        if let v = chargeStatus              { m.chargeStatus = v }
        if let v = idealEnergyRemaining      { m.idealEnergyRemaining = v }
        if let v = maxRegenPower             { m.maxRegenPower = v }
        if let v = maxDischargePower         { m.maxDischargePower = v }
        if let v = nominalFullPackNew        { m.nominalFullPackNew = v }
        if let v = nominalFullPackNow        { m.nominalFullPackNow = v }
        if let v = nominalRemaining          { m.nominalRemaining = v }
        if let v = energyBuffer              { m.energyBuffer = v }
        if let v = tempPtInlet               { m.tempPtInlet = v }
        if let v = tempBatteryInlet          { m.tempBatteryInlet = v }
        if let v = tempInletTarget           { m.tempInletTarget = v }
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
        Self.merge(autopilotBlindSpotRearLeft, autopilotBlindSpotRearLeftRaw,
                   into: &m.autopilotBlindSpotRearLeft, &m.autopilotBlindSpotRearLeftRaw)
        Self.merge(autopilotBlindSpotRearRight, autopilotBlindSpotRearRightRaw,
                   into: &m.autopilotBlindSpotRearRight, &m.autopilotBlindSpotRearRightRaw)
        if let v = autopilotHandsOnState     { m.autopilotHandsOnState = v }
        if let v = autopilotFollowDistance   { m.autopilotFollowDistance = v }
        if let v = autopilotSpeedLimit       { m.autopilotSpeedLimit = v }
        Self.merge(doorFrontLeft, doorFrontLeftRaw, into: &m.doorFrontLeft, &m.doorFrontLeftRaw)
        Self.merge(doorFrontRight, doorFrontRightRaw, into: &m.doorFrontRight, &m.doorFrontRightRaw)
        Self.merge(doorRearLeft, doorRearLeftRaw, into: &m.doorRearLeft, &m.doorRearLeftRaw)
        Self.merge(doorRearRight, doorRearRightRaw, into: &m.doorRearRight, &m.doorRearRightRaw)
        Self.merge(frunk, frunkRaw, into: &m.frunk, &m.frunkRaw)
        Self.merge(trunk, trunkRaw, into: &m.trunk, &m.trunkRaw)
        if let v = carLocked                 { m.carLocked = v }
        if let v = childUnlockLeft           { m.childUnlockLeft = v }
        if let v = childUnlockRight          { m.childUnlockRight = v }
        if let v = outsideTempC              { m.outsideTempC = v }
        if let v = brakeTempFrontLeft        { m.brakeTempFrontLeft = v }
        if let v = brakeTempFrontRight       { m.brakeTempFrontRight = v }
        if let v = brakeTempRearLeft         { m.brakeTempRearLeft = v }
        if let v = brakeTempRearRight        { m.brakeTempRearRight = v }
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
        Self.merge(mediaPlaybackStatus, mediaPlaybackStatusRaw,
                   into: &m.mediaPlaybackStatus, &m.mediaPlaybackStatusRaw)
        Self.merge(mediaNowPlayingSource, mediaNowPlayingSourceRaw,
                   into: &m.mediaNowPlayingSource, &m.mediaNowPlayingSourceRaw)
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

    /// A typed field travels with its raw number, and the number decides: a
    /// delta that carries one replaces both, so a value without a case clears
    /// the typed field instead of leaving the previous case standing. A typed
    /// value set by hand without a number replaces the case and drops the
    /// stale number.
    private static func merge<T>(_ value: T?, _ raw: UInt32?,
                                 into base: inout T?, _ baseRaw: inout UInt32?) {
        if let raw {
            base = value
            baseRaw = raw
        } else if let value {
            base = value
            baseRaw = nil
        }
    }
}

// MARK: - In units

/// The raw fields in SI units, with the scales seen in a Model 3 on 2026-10-19
/// (README, "Units"). nil where the field is.
public extension VehicleData {
    /// ``rangeMiles`` in km.
    var rangeKm: Double? { rangeMiles.map { Double($0) * 1.609344 } }

    var batteryVolts: Double? { batteryVoltage.map { Double($0) / 100 } }
    /// Negative while the pack gives energy.
    var batteryAmps: Double? { batteryCurrent.map { Double($0) / 10 } }
    /// Volts × amps: negative while the pack gives energy, positive while it charges.
    var batteryPowerKw: Double? {
        guard let volts = batteryVolts, let amps = batteryAmps else { return nil }
        return volts * amps / 1000
    }
    var maxRegenPowerKw: Double? { maxRegenPower.map { Double($0) / 100 } }
    var maxDischargePowerKw: Double? { maxDischargePower.map { Double($0) / 100 } }

    var nominalFullPackNewKwh: Double? { nominalFullPackNew.map { Double($0) / 10 } }
    var nominalFullPackNowKwh: Double? { nominalFullPackNow.map { Double($0) * 0.02 } }
    var nominalRemainingKwh: Double? { nominalRemaining.map { Double($0) * 0.02 } }
    var idealEnergyRemainingKwh: Double? { idealEnergyRemaining.map { Double($0) * 0.02 } }
    var energyBufferKwh: Double? { energyBuffer.map { Double($0) / 100 } }
    /// Energy the car can still use: ``nominalRemainingKwh`` less the buffer.
    var usableEnergyKwh: Double? {
        guard let remaining = nominalRemainingKwh, let buffer = energyBufferKwh else { return nil }
        return max(0, remaining - buffer)
    }

    var cellMaxVolts: Double? { cellMaxVoltage.map { Double($0) * 0.002 } }
    var cellMinVolts: Double? { cellMinVoltage.map { Double($0) * 0.002 } }

    var acChargeTotalKwh: Double? { acChargeTotal.map { Double($0) / 1000 } }
    var dcChargeTotalKwh: Double? { dcChargeTotal.map { Double($0) / 1000 } }
    var regenTotalKwh: Double? { regenTotal.map { Double($0) / 1000 } }
    var dischargeTotalKwh: Double? { dischargeTotal.map { Double($0) / 1000 } }

    var lowBusVolts: Double? { lowBusVoltage.map { Double($0) / 100 } }
    var lowBusAmps: Double? { lowBusCurrent.map { Double($0) / 10 } }
    var highBusVolts: Double? { highBusVoltage.map { Double($0) / 10 } }

    var currentTime: Date? { currentTimeSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
}

// MARK: - Enum sidecars
//
// Raw values are the Commander's wire values. Every typed field keeps its
// number in a `…Raw` sibling as well, so a value without a case is never lost.
// "The descriptor" below means the proto descriptors compiled into Enhauto's
// S3XY app 6.8.4. What is confirmed in the car: README, "Verify in the car".

/// Shifter position, field 66.
///
/// This declaration is the only place the mapping lives. Field 66 is a bare
/// `uint32` in the descriptor; the values are Tesla's DI_gear (0 invalid, 1 P,
/// 2 R, 3 N, 4 D, 7 SNA), confirmed in a Model 3 on 2026-10-19 by shifting
/// P → R → N → D → P (1 → 2 → 3 → 4 → 1). Enhauto's app reads it the same way on
/// its dashboard endpoint (`CDashboardData::UpdateGearValue`). 0 and 7 have no
/// case and only show up in ``VehicleData/gearRaw``.
public enum Gear: UInt32, Sendable { case park = 1, reverse = 2, neutral = 3, drive = 4 }

/// `TurnSignalStatus` in the descriptor: 0 off, 1 active low, 2 active high.
/// Both active values mean the indicator is on: they alternate with the lamp,
/// 2 lit and 1 dark, about 0.36 s each (seen in a Model 3 on 2026-10-19). The
/// `…Raw` fields keep them, for blinking in step with the car.
public enum TurnSignalStatus: UInt32, Sendable {
    case off = 0, on = 1

    init?(wireValue: UInt32) {
        switch wireValue {
        case 0: self = .off
        case 1, 2: self = .on
        default: return nil
        }
    }
}

/// `BlindSpotState` in the descriptor: 0 no warning, 1 warning level 1,
/// 2 warning level 2, 3 SNA (no case).
public enum BlindSpotState: UInt32, Sendable {
    case clear = 0, warning = 1

    init?(wireValue: UInt32) {
        switch wireValue {
        case 0: self = .clear
        case 1, 2: self = .warning
        default: return nil
        }
    }
}

/// `LatchStatus` in the descriptor: 0 SNA, 1 opened, 2 closed, 3 closing,
/// 4 opening, 5 ajar, 6 timeout, 7 default, 8 fault. Closing and opening count
/// as open; SNA, timeout, default and fault have no case. Seen in a Model 3 on
/// 2026-10-19: doors and frunk 1 and 2, the powered trunk 2 → 1 when opened
/// (no 4) and 1 → 3 → 2 when closed.
public enum LatchStatus: UInt32, Sendable {
    case closed = 2, open = 1, ajar = 5

    init?(wireValue: UInt32) {
        switch wireValue {
        case 1, 3, 4: self = .open
        case 2: self = .closed
        case 5: self = .ajar
        default: return nil
        }
    }
}

/// `MediaPlaybackStatus` in the descriptor, same values (1 and 2 seen with Spotify
/// and DAB radio).
public enum MediaPlaybackStatus: UInt32, Sendable { case stopped = 0, playing = 1, paused = 2 }
/// `MediaSourceType` in the descriptor, same values. Spotify came as 12, and DAB
/// radio as 13, which the descriptor calls US radio.
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
            case (11, 0):  (v.mediaPlaybackStatus, v.mediaPlaybackStatusRaw) = enumField(try r.readVarint(), MediaPlaybackStatus.init(rawValue:))
            case (12, 0):  (v.mediaNowPlayingSource, v.mediaNowPlayingSourceRaw) = enumField(try r.readVarint(), MediaSource.init(rawValue:))
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
            case (27, 0):  v.outsideTempC = zigzag32(try r.readVarint())
            // BMS
            case (28, 0):  v.batteryVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (29, 0):  v.batteryCurrent = zigzag32(try r.readVarint())
            case (30, 0):  v.chargeStatus = UInt32(truncatingIfNeeded: try r.readVarint())
            case (31, 0):  v.idealEnergyRemaining = UInt32(truncatingIfNeeded: try r.readVarint())
            case (32, 0):  v.maxRegenPower = UInt32(truncatingIfNeeded: try r.readVarint())
            case (33, 0):  v.maxDischargePower = UInt32(truncatingIfNeeded: try r.readVarint())
            case (34, 0):  v.nominalFullPackNew = UInt32(truncatingIfNeeded: try r.readVarint())
            case (35, 0):  v.nominalFullPackNow = UInt32(truncatingIfNeeded: try r.readVarint())
            case (36, 0):  v.nominalRemaining = UInt32(truncatingIfNeeded: try r.readVarint())
            case (37, 0):  v.energyBuffer = UInt32(truncatingIfNeeded: try r.readVarint())
            case (38, 0):  v.tempPtInlet = zigzag32(try r.readVarint())
            case (39, 0):  v.tempBatteryInlet = zigzag32(try r.readVarint())
            case (40, 0):  v.tempInletTarget = zigzag32(try r.readVarint())
            case (41, 0):  v.cellMaxTempC = zigzag32(try r.readVarint())
            case (42, 0):  v.cellMinTempC = zigzag32(try r.readVarint())
            case (43, 0):  v.cellMaxVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (44, 0):  v.cellMinVoltage = UInt32(truncatingIfNeeded: try r.readVarint())
            case (45, 0):  v.acChargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (46, 0):  v.dcChargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (47, 0):  v.regenTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (48, 0):  v.dischargeTotal = UInt32(truncatingIfNeeded: try r.readVarint())
            case (49, 0):  v.batteryHeatingState = UInt32(truncatingIfNeeded: try r.readVarint())
            // Drivetrain
            case (50, 0):  v.frontTorque = zigzag32(try r.readVarint())
            case (51, 0):  v.frontPowerKw = zigzag32(try r.readVarint())
            case (52, 0):  v.rearTorque = zigzag32(try r.readVarint())
            case (53, 0):  v.rearPowerKw = zigzag32(try r.readVarint())
            case (54, 0):  v.rearRightTorque = zigzag32(try r.readVarint())
            case (55, 0):  v.rearRightPowerKw = zigzag32(try r.readVarint())
            case (56, 0):  v.trackModeStability = UInt32(truncatingIfNeeded: try r.readVarint())
            case (57, 0):  v.trackModeHandling = UInt32(truncatingIfNeeded: try r.readVarint())
            case (58, 0):  v.tempFrontStatorC = zigzag32(try r.readVarint())
            case (59, 0):  v.tempRearStatorC = zigzag32(try r.readVarint())
            case (60, 0):  v.invertersCount = UInt32(truncatingIfNeeded: try r.readVarint())
            // Driving state
            case (61, 0):  v.speedKmh = UInt32(truncatingIfNeeded: try r.readVarint())
            case (62, 0):  v.accelPedalPercent = UInt32(truncatingIfNeeded: try r.readVarint())
            case (63, 0):  (v.turnSignalLeft, v.turnSignalLeftRaw) = enumField(try r.readVarint(), TurnSignalStatus.init(wireValue:))
            case (64, 0):  (v.turnSignalRight, v.turnSignalRightRaw) = enumField(try r.readVarint(), TurnSignalStatus.init(wireValue:))
            case (65, 0):  v.brakePressed = (try r.readVarint()) != 0
            case (66, 0):  (v.gear, v.gearRaw) = enumField(try r.readVarint(), Gear.init(rawValue:))
            case (67, 0):  v.regenLevel = UInt32(truncatingIfNeeded: try r.readVarint())
            case (68, 0):  v.driftModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (69, 0):  v.trackModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (70, 0):  v.accelerationMode = UInt32(truncatingIfNeeded: try r.readVarint())
            case (71, 0):  v.motorOnModeState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (72, 0):  v.tractionControl = UInt32(truncatingIfNeeded: try r.readVarint())
            case (73, 0):  v.stoppingMode = UInt32(truncatingIfNeeded: try r.readVarint())
            case (74, 0):  v.wiperSpeed = UInt32(truncatingIfNeeded: try r.readVarint())
            // Charging
            case (75, 0):  v.chargingDcCurrent = zigzag32(try r.readVarint())
            case (76, 0):  v.chargingDcVoltage = zigzag32(try r.readVarint())
            case (77, 0):  v.lowBusVoltage = zigzag32(try r.readVarint())
            case (78, 0):  v.lowBusCurrent = zigzag32(try r.readVarint())
            case (79, 0):  v.highBusVoltage = zigzag32(try r.readVarint())
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
            case (106, 0): (v.autopilotBlindSpotRearLeft, v.autopilotBlindSpotRearLeftRaw) = enumField(try r.readVarint(), BlindSpotState.init(wireValue:))
            case (107, 0): (v.autopilotBlindSpotRearRight, v.autopilotBlindSpotRearRightRaw) = enumField(try r.readVarint(), BlindSpotState.init(wireValue:))
            case (108, 0): v.autopilotHandsOnState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (109, 0): v.autopilotFollowDistance = UInt32(truncatingIfNeeded: try r.readVarint())
            case (110, 0): v.autopilotSpeedLimit = UInt32(truncatingIfNeeded: try r.readVarint())
            // Trip
            case (111, 0): v.socPercent = UInt32(truncatingIfNeeded: try r.readVarint())
            case (112, 0): v.rangeMiles = UInt32(truncatingIfNeeded: try r.readVarint())
            // Doors
            case (113, 0): (v.doorFrontLeft, v.doorFrontLeftRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (114, 0): (v.doorFrontRight, v.doorFrontRightRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (115, 0): (v.doorRearLeft, v.doorRearLeftRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (116, 0): (v.doorRearRight, v.doorRearRightRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (117, 0): (v.frunk, v.frunkRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (118, 0): (v.trunk, v.trunkRaw) = enumField(try r.readVarint(), LatchStatus.init(wireValue:))
            case (119, 0): v.carLocked = UInt32(truncatingIfNeeded: try r.readVarint())
            case (120, 0): v.childUnlockLeft = UInt32(truncatingIfNeeded: try r.readVarint())
            case (121, 0): v.childUnlockRight = UInt32(truncatingIfNeeded: try r.readVarint())
            // Misc
            case (122, 0): v.handWashState = UInt32(truncatingIfNeeded: try r.readVarint())
            case (123, 0): v.currentTimeSeconds = zigzag64(try r.readVarint())
            case (124, 0): v.rideAndHandling = UInt32(truncatingIfNeeded: try r.readVarint())
            case (125, 0): v.brakeTempFrontLeft = zigzag32(try r.readVarint())
            case (126, 0): v.brakeTempFrontRight = zigzag32(try r.readVarint())
            case (127, 0): v.brakeTempRearLeft = zigzag32(try r.readVarint())
            case (128, 0): v.brakeTempRearRight = zigzag32(try r.readVarint())
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

    /// An enum field: its case, if one matches, and always the number itself.
    @inline(__always)
    private static func enumField<T>(_ varint: UInt64, _ decode: (UInt32) -> T?) -> (T?, UInt32?) {
        let raw = UInt32(truncatingIfNeeded: varint)
        return (decode(raw), raw)
    }
}
