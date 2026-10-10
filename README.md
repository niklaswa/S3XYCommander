# S3XYCommander

Pure-Swift CoreBluetooth client for the **S3XY Commander**, the Tesla OBD-II dongle sold with the S3XY Buttons / Dash / Knob / Stalks accessories.

Reads live vehicle data straight off the car's CAN bus at **~10 Hz**: speed, SoC, range, gear, powers, lights, climate, autopilot, doors, nav, media (~130 signals in total).

```swift
import S3XYCommander

let client = S3XYCommanderClient()
let found = try await client.scan(timeout: 10)
try await client.connect(to: found[0], pairingAuthorizationHandler: self)
try await client.subscribeAll()

for await snap in client.vehicleData {
    print("\(snap.lastDelta.speedKmh ?? 0) km/h")
}
```

- 100 % Swift, no external deps (CryptoKit + CommonCrypto, both built-in)
- `async`/`await` + `AsyncStream`, SwiftUI-friendly
- iOS 16+, macOS 13+, tvOS 16+, visionOS 1+, Mac Catalyst 16+
- MIT

## Installation

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/niklaswa/S3XYCommander.git", branch: "main"),
],
```

Add to Info.plist:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connect to your S3XY Commander for live vehicle data.</string>
```

## Quick start

```swift
import S3XYCommander

final class AppVM: ObservableObject, PairingAuthorizationHandler {
    let client = S3XYCommanderClient()
    @Published var speed: UInt32 = 0

    func start() async throws {
        let found = try await client.scan(timeout: 10)
        guard let commander = found.first else { return }

        try await client.connect(to: commander, pairingAuthorizationHandler: self)
        try await client.subscribeAll()

        for await snap in client.vehicleData {
            if let s = snap.lastDelta.speedKmh { self.speed = s }
        }
    }

    // Shown by the client when the Commander doesn't recognise this phone yet.
    func commanderRequestsPhysicalAuthorization() async -> Bool {
        // Show your UI prompting the user, return true to retry.
        return true
    }
}
```

## First-time pairing

The Commander keeps an on-device allowlist of phone UUIDs. A **new** phone has to be authorised physically: the user sits in the car and **double-presses the right scroll button on the steering wheel**. The library wires this up for you. Just provide a `PairingAuthorizationHandler` and show a prompt in your UI while it waits.

## Signals

All available signals, each exposed as a typed property on `VehicleData` and a case on `VehicleSignal` (pass to `subscribeAll(fields:)` or `nil` for everything).

The firmware pushes **only deltas**; each snapshot carries only fields that changed. `CommanderObservation.accumulated` keeps a merged "current full state" view for you.

### Driving state
`drivingStateSpeed` (km/h) · `drivingStateAccelPedalPos` (%) · `drivingStateTurnSignalLeft/Right` · `drivingStateBrakePressed` · `drivingStateGear` (P/R/N/D) · `drivingStateRegenLevel` · `drivingStateDriftModeState` · `drivingStateTrackModeState` · `drivingStateAccelerationMode` · `drivingStateMotorOnModeState` · `drivingStateTractionControl` · `drivingStateStoppingMode` · `drivingStateWiperSpeed`

### Trip
`tripDataUsoe` (usable SoC %) · `tripDataRange` (km / mi per display units)

### Battery / BMS
`bmsBatteryVoltage` · `bmsBatteryCurrent` · `bmsChargeStatus` · `bmsIdealEnergyRemaining` · `bmsMaxRegenPower` / `MaxDischargePower` (kW) · `bmsNominalFullPackNew` / `Now` / `Remaining` / `EnergyBuffer` (kWh × 10) · `bmsTempPtInlet` / `TempBatteryInlet` / `TempInletTarget` (°C) · `bmsCellMaxTemp` / `MinTemp` · `bmsCellMaxVoltage` / `MinVoltage` · `bmsAcChargeTotal` · `bmsDcChargeTotal` · `bmsRegenTotal` · `bmsDischargeTotal` · `bmsBatteryHeatingState`

### Drivetrain
`drivetrainFrontTorque` / `FrontPower` (kW, signed; negative = regen) · `drivetrainRearTorque` / `RearPower` · `drivetrainRearRightTorque` / `RearRightPower` (tri-motor) · `drivetrainTempFrontStator` / `TempRearStator` · `drivetrainInvertersCount` · `drivetrainTrackModeStability` / `TrackModeHandling` / `RideAndHandling`

### Charging
`chargingDcCurrent` · `chargingDcVoltage` · `chargingLowBusVoltage` · `chargingLowBusCurrent` · `chargingHighBusVoltage`

### Lights
`lightsDrl` · `lightsLowBeam` · `lightsHighBeam` · `lightsFogFront` · `lightsFogRear` · `lightsPark` · `lightsAutoHighBeamEnabled` · `lightsAutoLights`

### Climate
`climateFanSpeed` · `climateHvacOn` · `climateAcToggle` · `climateRecirculationToggle` · `climateKeeperMode` · `climateBioweaponDefence` · `climateVentWindows` · `climateRearVentToggle` · `climateDefogDefrost` · `climateSteeringWheelHeater` · `climateHeatedSeatsFl` / `Fr` / `Rl` / `Rc` / `Rr` · `climateSeatCoolingFl` / `Fr`

### Autopilot
`autopilotCurrentState` · `autopilotBlindSpotRearLeft` / `RearRight` · `autopilotHandsOnState` · `autopilotFollowDistance` · `autopilotSpeedLimit`

### Doors / latches
`latchFrontLeftDoor` · `latchFrontRightDoor` · `latchRearLeftDoor` · `latchRearRightDoor` · `latchFrunk` · `latchTrunk` · `latchCarLocked` · `latchChildUnlockLeft` / `Right`

### Sensors
`outsideTemperature` · `sensorsFrontLeftBrakeTemp` · `sensorsFrontRightBrakeTemp` · `sensorsRearLeftBrakeTemp` · `sensorsRearRightBrakeTemp`

### Navigation
`navCarLatitude` / `navCarLongitude` (Float) · `navCarLocationName` · `navDestinationLatitude` / `Longitude` / `LocationName` · `navDistanceInMiles` · `navMinutesToArrival` · `navEnergyAtArrival` · `navTrafficMinutesDelay`

### Media
`mediaPlaybackStatus` · `mediaNowPlayingSource` (AM/FM/Spotify/Tidal/SiriusXM/…) · `mediaNowPlayingArtist` / `Title` / `Album` / `Station` · `mediaNowPlayingDurationSec` / `ElapsedSec` · `mediaAudioVolume` / `Max` / `Increment`

### Display + misc
`displayBrightness` / `State` / `Theme` · `driverOrPassengerPresent` · `othersHandWashState` · `othersCurrentTimeInSeconds`

## Verify in the car

Not every enum mapping has been checked against a real car. Every typed enum field keeps the number the Commander sent in a `…Raw` sibling (`gearRaw`, `turnSignalLeftRaw`, `autopilotBlindSpotRearLeftRaw`, `doorFrontLeftRaw`, `mediaPlaybackStatusRaw`, …). A value without a case still arrives there, and the typed field reads `nil`. `autopilotCurrentState` and `autopilotHandsOnState` are plain numbers already.

Print the raw values:

```swift
for await snap in client.vehicleData {
    let car = snap.accumulated
    print("gear", car.gearRaw ?? 0,
          "signal L/R", car.turnSignalLeftRaw ?? 0, car.turnSignalRightRaw ?? 0,
          "blind spot L/R", car.autopilotBlindSpotRearLeftRaw ?? 0, car.autopilotBlindSpotRearRightRaw ?? 0,
          "AP", car.autopilotCurrentState ?? 0, "hands", car.autopilotHandsOnState ?? 0)
}
```

Close the S3XY app first. Anything that needs the car moving is read by a passenger.

1. **Gear.** Foot on the brake, shift P → R → N → D and note `gearRaw` each time. Expected: P 1, R 2, N 3, D 4. If the car says otherwise, change the numbers in `enum Gear` in `VehicleData.swift`. The mapping lives only there.
2. **Turn signals.** Tap the stalk (three blinks), then push it through to the stop, left and right. Expected: 0 while off, 1 or 2 while blinking. Note whether 1 and 2 alternate with the blink or depend on how far the stalk is pushed.
3. **Blind spot.** On a multi-lane road, with a car alongside in the neighbouring lane, then with the indicator on towards it. Expected: 0 clear, 1 and 2 warning levels, 3 not available.
4. **Autopilot.** Note `autopilotCurrentState` while off, with cruise control (TACC), with Autosteer, and on Navigate on Autopilot. If this is Tesla's DAS_autopilotState: 2 available, 3 active, 4 active but restricted, 5 Navigate on Autopilot. Hands off the wheel until the warning comes: `autopilotHandsOnState` should go 0 → 3 (visual) → 4/5 (chime).
5. **Doors.** Open and close every door, the frunk and the trunk. Expected: 1 open, 2 closed. A powered trunk shows 4 while opening and 3 while closing.

What is known about each mapping. "Descriptor" means the field's enum type and value names are in the proto descriptors compiled into Enhauto's S3XY app 6.8.4. Nothing in this table has been checked in the car yet.

| Field | Mapping | Basis | In the car |
|---|---|---|---|
| `gear` (66) | 1 P, 2 R, 3 N, 4 D; 0 invalid and 7 SNA have no case | **Not from the descriptor**, which types the field as a bare `uint32`. These are Tesla's DI_gear values, and Enhauto's app reads the Commander's gear that way on its dashboard endpoint (2 R, 3 N, 4 D, anything else P). | open |
| `turnSignalLeft` / `Right` (63/64) | 0 off; 1 (active low) and 2 (active high) both read as `.on` | Descriptor `TurnSignalStatus`. What separates 1 from 2 is unknown. | open |
| `autopilotBlindSpotRearLeft` / `Right` (106/107) | 0 clear; 1 and 2 (warning levels) read as `.warning`; 3 SNA has no case | Descriptor `BlindSpotState` | open |
| doors, `frunk`, `trunk` (113–118) | 1 opened, 2 closed, 3 closing, 4 opening, 5 ajar; closing and opening read as `.open`; 0 SNA, 6 timeout, 7 default and 8 fault have no case | Descriptor `LatchStatus` | open |
| `autopilotCurrentState` (105) | plain number | **Unknown.** A bare `uint32` in the descriptor. It may be Tesla's DAS_autopilotState (as in the dashboard push) or Enhauto's own `CurrApState`. | open |
| `autopilotHandsOnState` (108) | plain number; values in the property's doc comment | Descriptor `AutopilotHandsOnState` | open |
| `mediaPlaybackStatus` (11) | 0 stopped, 1 playing, 2 paused | Descriptor `MediaPlaybackStatus` | open |
| `mediaNowPlayingSource` (12) | see `MediaSource` | Descriptor `MediaSourceType` | open |

## Actions

Fire one-shot actions on the Tesla's CAN bus, equivalent to pressing a
steering-wheel / stalk / screen control from code:

```swift
try await client.tryAction(.hazardLights)            // flash hazards
try await client.tryAction(.openFrunk)               // pop frunk
try await client.tryAction(.foldMirrors)             // fold mirrors
try await client.tryAction(.cabinTemp, states: [22]) // set 22 °C
try await client.tryAction(.autopilotSpeedAdjust, states: [120])
try await client.tryAction(.highBeamStrobe, states: [5])  // 5× strobe
try await client.tryAction(.frontSeatHeatLeft, states: [3])  // level 3
```

All 100 ``TeslaAction`` cases are available, covering:

- **Doors / windows / frunk / trunk / charge port** · `openFrunk` · `openTrunk` · `openDoor` · `unlockCar` · `childUnlock` · `frontLeftWindow` / `frontRightWindow` / `rearLeftWindow` / `rearRightWindow` · `ventWindows` · `chargePort` · `openGloveBox`
- **Lights** · `headlights` · `interiorLights` · `frontFogLights` / `rearFogLights` / `allFogLights` · `backWindowHeater` · `hazardLights` · `highBeamStrobe` · `dynamicBrakeLights` · `lightsControl` · `plaidLightsControl` · `lightStripBrightness`
- **Climate** · `hvacOn` · `hvacBlower` · `hvacDefogDefrost` · `hvacSecondRowState` · `cabinTemp` / `cabinTempLeft` / `cabinTempRight` · `keepClimateOn` · `recirc` · `acDisable` · `bioweaponDefence` · `dogMode` · `campMode` · `partyMode` · `precondition_` · `ventLeft` / `ventRight`
- **Seats** · `frontSeatHeatLeft` / `Right` · `rearSeatHeatLeft` / `Right` / `Central` / `All` · `allSeatHeat` · `frontSeatVentLeft` / `Right` · `driverMoveSeat` · `passengerMoveSeat` · `set/restoreLeftSeatProfile` · `set/restoreRightSeatProfile` · `set/restorePassengerEasyEntrySeatProfile` · `leftSeatMassage` · `rightSeatMassage` · `steeringWheelHeat`
- **Driving** · `autopilotStart` / `autopilotExtended` / `autopilotMax` · `autopilotSpeedAdjust` · `cruiseControlStart` · `followDistance` · `speedControl` · `gearShift` · `simulatePark` · `parkBrake` · `tractionControl` · `stoppingMode` · `driveModeAccel` / `Regen` / `Steering` · `disableMotor`
- **Track mode** · `trackMode` · `trackModeStability` · `trackModeHandling`
- **Wipers & mirrors** · `wiperMode` · `wipersHeat` · `wipersWasher` · `foldMirrors` · `mirrorsDip` · `mirrorsDim`
- **Horn / signals / misc** · `honkHorn` · `voiceCommand` · `grok` · `thankYou` · `seatBeltsWarning` · `screenTilt` · `rearViewCamera` · `handWash` · `sentryMode` · `rideHandling` · `sounds` · `suspension` · `mediaControl`

**Note:** actions require a non-empty `states` array (the firmware rejects empty state lists with `InvalidArgument`). The default `[1]` works for all simple toggle actions; for actions with numeric arguments pass the desired value.

## Notes

- **Only one BLE client at a time.** If the official S3XY app is connected, the Commander won't be visible to anyone else. Close the other app first.
- Multiple phones **can** be paired long-term; the on-device allowlist holds at least 3. The physical steering-wheel double-press is a per-pairing one-off.
- Device identity is a random UUID generated on first launch and persisted via `UserDefaults` (`s3xycommander.phoneUUID`); override via `Config.phoneUUID` to bring your own.
- All work happens on-device; no network calls, no cloud.

## License

MIT. See `LICENSE`.
