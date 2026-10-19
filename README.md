# S3XYCommander

Pure-Swift CoreBluetooth client for the **S3XY Commander**, the Tesla OBD-II dongle sold with the S3XY Buttons / Dash / Knob / Stalks accessories.

Reads live vehicle data at **~10 Hz**: speed, SoC, range, gear, battery, lights, climate, autopilot, doors (~130 signals, off the car's CAN bus), the steering wheel's scroll wheels, and the car's navigation and media, which the Commander reads from the car's API when it is paired with the car as a key (Enhauto's "Tesla API" add-on).

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

Every field is a property of `VehicleData`, and a case of `VehicleSignal` to pass to `subscribeAll(fields:)` (`nil` subscribes to everything).

The firmware pushes **only deltas**; each snapshot carries only fields that changed. `CommanderObservation.accumulated` keeps a merged "current full state" view for you.

Fields hold the numbers the Commander sends. Where the scale is known, the doc comment says so and a converted property in SI units sits next to it (see [Units](#units)); a unit in a property's name is a confirmed one.

### Driving state
`speedKmh` · `accelPedalPercent` · `turnSignalLeft` / `Right` · `brakePressed` · `gear` (P/R/N/D) · `regenLevel` · `driftModeState` · `trackModeState` · `accelerationMode` · `motorOnModeState` · `tractionControl` · `stoppingMode` · `wiperSpeed`

### Trip
`socPercent` (the charge the car shows) · `rangeMiles` → `rangeKm`

### Battery / BMS
`batteryVoltage` → `batteryVolts` · `batteryCurrent` → `batteryAmps`, `batteryPowerKw` · `chargeStatus` · `idealEnergyRemaining` → `…Kwh` · `maxRegenPower` / `maxDischargePower` → `…Kw` · `nominalFullPackNew` / `nominalFullPackNow` / `nominalRemaining` / `energyBuffer` → `…Kwh`, `usableEnergyKwh` · `tempPtInlet` / `tempBatteryInlet` / `tempInletTarget` · `cellMaxTempC` / `cellMinTempC` · `cellMaxVoltage` / `cellMinVoltage` → `…Volts` · `acChargeTotal` / `dcChargeTotal` / `regenTotal` / `dischargeTotal` → `…Kwh` · `batteryHeatingState`

### Drivetrain
`frontTorque` / `frontPowerKw` · `rearTorque` / `rearPowerKw` · `rearRightTorque` / `rearRightPowerKw` (tri-motor) · `tempFrontStatorC` / `tempRearStatorC` · `invertersCount` · `trackModeStability` / `trackModeHandling` / `rideAndHandling`

### Charging
`chargingDcCurrent` · `chargingDcVoltage` · `lowBusVoltage` / `lowBusCurrent` → `lowBusVolts` / `lowBusAmps` · `highBusVoltage` → `highBusVolts`

### Lights
`lightsDrl` · `lightsLowBeam` · `lightsHighBeam` · `lightsFogFront` · `lightsFogRear` · `lightsPark` · `autoHighBeamEnabled` · `autoLights`

### Climate
`climateFanSpeed` · `climateHvacOn` · `climateAcToggle` · `climateRecirculationToggle` · `climateKeeperMode` · `climateBioweaponDefence` · `climateVentWindows` · `climateRearVentToggle` · `climateDefogDefrost` · `climateSteeringWheelHeater` · `climateHeatedSeatsFL` / `FR` / `RL` / `RC` / `RR` · `climateSeatCoolingFL` / `FR`

### Autopilot
`autopilotCurrentState` · `autopilotBlindSpotRearLeft` / `Right` · `autopilotHandsOnState` · `autopilotFollowDistance` · `autopilotSpeedLimit`

### Doors / latches
`doorFrontLeft` / `doorFrontRight` / `doorRearLeft` / `doorRearRight` · `frunk` · `trunk` · `carLocked` · `childUnlockLeft` / `Right`

### Sensors
`outsideTempC` · `brakeTempFrontLeft` / `FrontRight` / `RearLeft` / `RearRight`

### Navigation (from the car's API)
`navCarLatitude` / `navCarLongitude` · `navCarLocationName` · `navDestinationLatitude` / `Longitude` / `LocationName` · `navDistanceInMiles` · `navMinutesToArrival` · `navEnergyAtArrival` · `navTrafficMinutesDelay`

### Media (from the car's API)
`mediaPlaybackStatus` · `mediaNowPlayingSource` · `mediaNowPlayingArtist` / `Title` / `Album` / `Station` / `SourceString` · `mediaA2dpSourceName` · `mediaNowPlayingDurationSec` / `ElapsedSec` · `mediaAudioVolume` / `Max` / `Increment`

### Display + misc
`displayBrightness` / `State` / `Theme` · `driverOrPassengerPresent` · `handWashState` · `currentTimeSeconds` → `currentTime`

## Units

Worked out in a Model 3 on 2026-10-19 from values that have to agree with each other; `RecordedPushTests` keeps the recorded pushes.

| Field | Scale | How it was pinned down |
|---|---|---|
| `nominalFullPackNow`, `nominalRemaining`, `idealEnergyRemaining` | 0.02 kWh | (remaining − buffer) / (full − buffer) gives `socPercent` exactly |
| `energyBuffer` | 0.01 kWh | the same equation |
| `nominalFullPackNew` | 0.1 kWh | the only scale that gives a plausible pack (78.8 kWh) |
| `batteryVoltage` | 0.01 V | equals `highBusVoltage` |
| `highBusVoltage` | 0.1 V | equals `batteryVoltage` |
| `batteryCurrent` | 0.1 A, negative while discharging | parked, volts × amps matches what the low-voltage side draws |
| `lowBusVoltage` / `lowBusCurrent` | 0.01 V / 0.1 A | 15.6 V, the 16 V battery |
| `cellMaxVoltage` / `cellMinVoltage` | 0.002 V | 4.05 V at 78 % |
| `maxRegenPower` / `maxDischargePower` | 0.01 kW | 77 kW / 288 kW |
| `acChargeTotal` … `dischargeTotal` | Wh | plausible lifetime totals |
| `rangeMiles` | miles, whatever the car displays | did not match the car's km; fits the pack in miles |
| `currentTimeSeconds` | seconds since 1970 (`sint64`) | the time of day, sent once a minute |
| `outsideTempC`, `tempFrontStatorC`, `cellMaxTempC` … | °C | 16 °C outside, stators at 17–18 parked |

Encoding: every signed field of the push is `sint32` (zigzag), except the media durations, which are `int32`. Read as a plain varint a zigzag value comes out doubled, and a negative one positive.

Still unknown: the drivetrain's torque and power, `speedKmh` and `accelPedalPercent` (all 0 parked), the DC charging values, the coolant temperatures (131 / 127 / 120 parked: 0.1 °C or 0.25 °C), and the brake temperatures (6–11 parked, below the outside air).

## Steering wheel

The scroll wheels arrive as events of their own, after asking for them:

```swift
try await client.subscribeSteeringWheelEvents()
for await event in client.steeringWheelEvents {
    if let ticks = event.rightScrollTicks, ticks != 0 { print("right wheel", ticks > 0 ? "up" : "down") }
    if event.leftPressed == .on { print("left wheel pressed") }
}
```

Pressing and tilting come as `SwitchState.on`, then `.off`; turning as the steps since the last push (1 to 3), then 0. A double press of the right wheel is also how a new phone is allowed (see [First-time pairing](#first-time-pairing)).

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

1. **Gear.** Foot on the brake, shift P → R → N → D and note `gearRaw` each time. Expected: P 1, R 2, N 3, D 4. If the car says otherwise, change the numbers in `enum Gear` in `VehicleData.swift`. The mapping lives only there. Done on 2026-10-19: the car matched.
2. **Turn signals.** Tap the stalk (three blinks), then push it through to the stop, left and right. Expected: 0 while off, 1 or 2 while blinking. Note whether 1 and 2 alternate with the blink or depend on how far the stalk is pushed. Done on 2026-10-19: they alternate with the blink.
3. **Blind spot.** On a multi-lane road, with a car alongside in the neighbouring lane, then with the indicator on towards it. Expected: 0 clear, 1 and 2 warning levels, 3 not available.
4. **Autopilot.** Note `autopilotCurrentState` while off, with cruise control (TACC), with Autosteer, and on Navigate on Autopilot. If this is Tesla's DAS_autopilotState: 2 available, 3 active, 4 active but restricted, 5 Navigate on Autopilot. Hands off the wheel until the warning comes: `autopilotHandsOnState` should go 0 → 3 (visual) → 4/5 (chime).
5. **Doors.** Open and close every door, the frunk and the trunk. Expected: 1 open, 2 closed. A powered trunk shows 4 while opening and 3 while closing. Done on 2026-10-19 except the rear doors: 1 and 2, and 3 while the trunk closed; it went straight to 1 when opening.

What is known about each mapping. "Descriptor" means the field's enum type and value names are in the proto descriptors compiled into Enhauto's S3XY app 6.8.4.

| Field | Mapping | Basis | In the car |
|---|---|---|---|
| `gear` (66) | 1 P, 2 R, 3 N, 4 D; 0 invalid and 7 SNA have no case | **Not from the descriptor**, which types the field as a bare `uint32`. These are Tesla's DI_gear values, and Enhauto's app reads the Commander's gear that way on its dashboard endpoint (2 R, 3 N, 4 D, anything else P). | confirmed 2026-10-19 (Model 3, P→R→N→D→P gave 1→2→3→4→1) |
| `turnSignalLeft` / `Right` (63/64) | 0 off; 1 (active low) and 2 (active high) both read as `.on` | Descriptor `TurnSignalStatus`. 1 and 2 alternate with the lamp: 2 lit, 1 dark, about 0.36 s each. | confirmed 2026-10-19 (Model 3) |
| `autopilotBlindSpotRearLeft` / `Right` (106/107) | 0 clear; 1 and 2 (warning levels) read as `.warning`; 3 SNA has no case | Descriptor `BlindSpotState` | open |
| doors, `frunk`, `trunk` (113–118) | 1 opened, 2 closed, 3 closing, 4 opening, 5 ajar; closing and opening read as `.open`; 0 SNA, 6 timeout, 7 default and 8 fault have no case | Descriptor `LatchStatus` | confirmed 2026-10-19 for the front doors, frunk and trunk: 1 and 2; the powered trunk went 2 → 1 opening (no 4) and 1 → 3 → 2 closing |
| `carLocked` (119) | 1 locked, 0 unlocked | bare `uint32` | confirmed 2026-10-19 |
| `autopilotCurrentState` (105) | plain number | **Unknown.** A bare `uint32` in the descriptor. It may be Tesla's DAS_autopilotState (as in the dashboard push) or Enhauto's own `CurrApState`. | open |
| `autopilotHandsOnState` (108) | plain number; values in the property's doc comment | Descriptor `AutopilotHandsOnState` | 1 and 2 confirmed 2026-10-19 (parked, hands on the wheel's rollers); the warnings need a drive |
| `mediaPlaybackStatus` (11) | 0 stopped, 1 playing, 2 paused | Descriptor `MediaPlaybackStatus` | 1 and 2 confirmed 2026-10-19 |
| `mediaNowPlayingSource` (12) | see `MediaSource` | Descriptor `MediaSourceType` | Spotify 12 confirmed; DAB radio came as 13, `usRadio` in the descriptor |
| lights (80–85) | 0 off, 17 on; the rear fog lamp 1 | bare `uint32`; looks like one bit per side (0x01, 0x10), with a single rear fog lamp | seen 2026-10-19 |
| `autoLights` (87) | 0 auto, 1 on, 3 off | Descriptor `LightSwitchStatus` | confirmed 2026-10-19 |
| `climateHeatedSeatsFL` …, `climateSeatCoolingFL` … | levels 0–3 | bare `uint32` | seen 2026-10-19 |
| `climateHvacOn`, `climateDefogDefrost` | 0/1; 1 defog | | confirmed 2026-10-19 |

Not sent at all in that car, with the volume turned and Spotify and DAB radio playing: `mediaAudioVolume`, `…Increment`, `…Max`; `mediaNowPlayingDurationSec` and `…ElapsedSec` stay 0, and `navCarLatitude` / `Longitude` 0 while `navCarLocationName` comes. `climateSteeringWheelHeater`, `climateFanSpeed` and `wiperSpeed` did not change when expected; still to be checked.

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

## Tools

`Tools/CommanderProbe` is a Mac app that connects to the Commander and shows and logs every push, raw and decoded with the names from the firmware's descriptors: how the units above were worked out. `./run.sh` builds and starts it; see its README. Its logs hold what the car reports, destinations and songs included, and stay in its `logs/` folder, which git ignores.

## Notes

- **Only one BLE client at a time.** If the official S3XY app is connected, the Commander won't be visible to anyone else. Close the other app first.
- Multiple phones **can** be paired long-term; the on-device allowlist holds at least 3. The physical steering-wheel double-press is a per-pairing one-off.
- Device identity is a random UUID generated on first launch and persisted via `UserDefaults` (`s3xycommander.phoneUUID`); override via `Config.phoneUUID` to bring your own.
- All work happens on-device; no network calls, no cloud.

## License

MIT. See `LICENSE`.
