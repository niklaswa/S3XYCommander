import Foundation
import CoreBluetooth
import OSLog

// MARK: - Public configuration

/// Static library-wide constants.
public enum S3XYCommander {
    /// The GATT service UUID the Commander advertises. Fixed in firmware.
    public static let serviceUUID = CBUUID(string: "5857A678-87C6-11EB-8DCD-0242AC130003")

    /// Proof-of-Possession string for the Security1 handshake. Hardcoded in
    /// the Enhauto firmware; same on every Commander ever shipped. See
    /// README §Reversing-Notes for how this was extracted.
    public static let defaultPOP = "s3xy_enh"

    /// The six protocomm endpoints the Enhauto firmware exposes. For debug.
    public enum Endpoint {
        public static let session   = "prov-session"
        public static let protoVer  = "proto-ver"
        public static let cmd       = "enhapi"
        public static let push      = "push-enhapi"
        public static let cmdFast   = "cmd-enhapi"
        public static let cmdFaster = "cmd-fast"
    }
}

/// High-level connection phase (useful for driving UI state).
public enum CommanderPhase: Sendable, Equatable {
    case idle
    case scanning
    case connecting
    case discovering
    case handshake
    case registering
    case subscribing
    case streaming
    case disconnected
    case failed(String)
}

/// Delegate protocol the host app implements to react to pairing prompts.
public protocol PairingAuthorizationHandler: AnyObject, Sendable {
    /// Called when the Commander rejects our SendUUID (meaning our UUID is
    /// not in its allowlist). Return `true` to retry the authorization flow
    /// after the user physically double-presses the right steering-wheel
    /// scroll button in the car; return `false` to abort the connection
    /// attempt.
    ///
    /// After returning `true`, the client re-attempts the handshake + SendUUID
    /// a few seconds later. Repeat as needed until the user has pressed the
    /// button, or `false` to give up.
    func commanderRequestsPhysicalAuthorization() async -> Bool
}

/// Snapshot of what the Commander currently publishes. Published to the UI
/// via ``S3XYCommanderClient/latest``.
public struct CommanderObservation: Sendable {
    public var phase: CommanderPhase
    public var deviceName: String?
    public var pushCount: Int
    /// The last decoded delta.
    public var lastDelta: VehicleData
    /// A rolling accumulator of all signals seen so far this session.
    public var accumulated: VehicleData
}

// MARK: - Client

/// The main entry point. One instance per connection. Create once, call
/// ``scan(timeout:)`` to find a Commander, then ``connect(to:pairingAuthorizationHandler:)``,
/// then iterate ``vehicleData`` for live updates.
///
/// Threading: all public methods are `@MainActor`. Internals do their own
/// serialisation.
///
/// Example:
/// ```swift
/// let client = S3XYCommanderClient()
/// let commander = try await client.scan(timeout: 15).first!
/// try await client.connect(to: commander, pairingAuthorizationHandler: self)
///
/// try await client.subscribeAll()
/// for await snapshot in client.vehicleData {
///     print(snapshot.lastDelta.speedKmh ?? 0, "km/h")
/// }
/// ```
@MainActor
public final class S3XYCommanderClient: NSObject {

    // ─── Config ─────────────────────────────────────────────────
    public struct Config: Sendable {
        /// POP for the Security1 handshake. Defaults to the Enhauto value.
        public var pop: String = S3XYCommander.defaultPOP
        /// Whether to request the firmware's "unencrypted push data" mode.
        /// Keeps `cmd-*` traffic encrypted; just lifts encryption off the
        /// vehicle-data push stream so the client decodes less. Default on.
        public var disablePushEncryption: Bool = true
        /// Set the stable per-install phone UUID. If nil, the library
        /// generates a random `{lowercase-uuid}` and persists it under
        /// `UserDefaults` key `s3xycommander.phoneUUID`.
        public var phoneUUID: String? = nil
        /// Device type reported in SessionCmd1. The Enhauto app uses PHONE=1.
        public var deviceType: Int32 = 1
        /// Logger subsystem.
        public var logSubsystem: String = "s3xycommander"
        public init() {}
    }

    public private(set) var config: Config
    private let logger: Logger

    public init(config: Config = Config()) {
        self.config = config
        self.logger = Logger(subsystem: config.logSubsystem, category: "client")
        super.init()
    }

    // ─── BLE state ──────────────────────────────────────────────
    private var central: CBCentralManager!
    private var discoveredByID: [UUID: DiscoveredCommander] = [:]
    private var activePeripheral: CBPeripheral?
    private var endpoints: [String: CBCharacteristic] = [:]
    private var descsLeft = 0

    // ─── Session state ──────────────────────────────────────────
    private var sec: Security1?
    private var pushPlaintext = true
    private(set) var currentPhase: CommanderPhase = .idle {
        didSet { publishLatest() }
    }
    private var pushCount = 0
    private var latestDelta = VehicleData()
    private var accumulated = VehicleData()

    private var pairingHandler: PairingAuthorizationHandler?

    // ─── Async continuations ────────────────────────────────────
    private var scanContinuation: CheckedContinuation<[DiscoveredCommander], Error>?
    private var scanResults: [DiscoveredCommander] = []
    private var connectContinuation: CheckedContinuation<Void, Error>?

    // Response matchers
    private var pendingSessionRead: ((Result<Data, Error>) -> Void)?
    private var pendingCmdRead: ((Result<Data, Error>) -> Void)?

    private var vehicleDataContinuations: [UUID: AsyncStream<CommanderObservation>.Continuation] = [:]
    private var latestObservation: CommanderObservation {
        CommanderObservation(
            phase: currentPhase,
            deviceName: activePeripheral?.name,
            pushCount: pushCount,
            lastDelta: latestDelta,
            accumulated: accumulated
        )
    }

    /// The resolved phone UUID currently being used (persistent across launches).
    public var phoneUUID: String {
        if let o = config.phoneUUID { return o }
        let key = "s3xycommander.phoneUUID"
        if let s = UserDefaults.standard.string(forKey: key), s.hasPrefix("{") { return s }
        let s = "{\(UUID().uuidString.lowercased())}"
        UserDefaults.standard.set(s, forKey: key)
        return s
    }

    private func lazyCentral() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // ─── Public API ─────────────────────────────────────────────

    /// Scan for Commanders. Returns the list after `timeout` seconds, or
    /// as soon as at least one is found and `timeout` has elapsed.
    @discardableResult
    public func scan(timeout: TimeInterval = 10) async throws -> [DiscoveredCommander] {
        lazyCentral()
        try await waitForBluetoothPowerOn()

        discoveredByID.removeAll()
        scanResults = []
        currentPhase = .scanning
        logger.info("scanning for \(S3XYCommander.serviceUUID.uuidString)")
        central.scanForPeripherals(withServices: [S3XYCommander.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        return try await withCheckedThrowingContinuation { cont in
            scanContinuation = cont
            // Schedule timeout
            Task.detached { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self = self else { return }
                if self.central.isScanning { self.central.stopScan() }
                self.scanContinuation?.resume(returning: self.scanResults)
                self.scanContinuation = nil
                if self.currentPhase == .scanning { self.currentPhase = .idle }
            }
        }
    }

    /// Connect, perform Security1 handshake, register our phone UUID, and
    /// leave the session ready for ``subscribeAll(fields:)``.
    ///
    /// If the firmware rejects our SendUUID (new UUID not in allowlist),
    /// the `pairingAuthorizationHandler` is invoked. The host app typically
    /// shows a UI telling the user to double-press the right steering wheel
    /// scroll button, then returns `true` to retry.
    public func connect(
        to discovered: DiscoveredCommander,
        pairingAuthorizationHandler: PairingAuthorizationHandler? = nil
    ) async throws {
        lazyCentral()
        try await waitForBluetoothPowerOn()

        self.pairingHandler = pairingAuthorizationHandler
        self.activePeripheral = discovered.peripheral
        discovered.peripheral.delegate = self

        currentPhase = .connecting
        logger.info("connecting to \(discovered.name ?? "unknown")")

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.connectContinuation = cont
            self.central.connect(discovered.peripheral)
        }

        try await discover()
        try await runHandshakeAndRegistration()
    }

    /// Subscribe to vehicle data. Pass nil to subscribe to everything (what
    /// the Enhauto app does); pass a specific list of ``VehicleSignal`` to
    /// request only those. Returns when the subscribe is acknowledged.
    public func subscribeAll(fields: [VehicleSignal]? = nil) async throws {
        guard let sec = sec, let cmdCh = endpoints[S3XYCommander.Endpoint.cmd] else {
            throw CommanderError.notSessionReady
        }
        currentPhase = .subscribing
        let plain = Build.subscribeVehicleData(fields: fields?.map { UInt64($0.rawValue) })
        let enc = sec.encrypt(plain)
        logger.info("subscribe (\(fields?.count ?? -1) fields)")
        let resp = try await writeAndRead(cmd: enc, on: cmdCh)
        let plainResp = sec.decrypt(resp)
        let (_, status) = try Parse.respStatus(plainResp)
        guard status == .success else { throw CommanderError.subscribeRejected(status: status) }
        currentPhase = .streaming
    }

    /// AsyncStream of ``CommanderObservation`` snapshots, one per push the
    /// Commander sends. Suitable for driving SwiftUI with `.task { for await
    /// obs in client.vehicleData { ... } }`.
    public var vehicleData: AsyncStream<CommanderObservation> {
        AsyncStream { continuation in
            let id = UUID()
            // Emit current state immediately so late subscribers aren't blank.
            continuation.yield(latestObservation)
            Task { @MainActor [weak self] in
                self?.vehicleDataContinuations[id] = continuation
            }
            continuation.onTermination = { _ in
                Task { @MainActor [weak self] in
                    self?.vehicleDataContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Fire a one-shot action - tell the Commander to emulate a steering-wheel
    /// / stalk / screen button press on the Tesla's CAN bus. Equivalent to
    /// what the official S3XY app's "Try Action" button does.
    ///
    /// Examples:
    /// ```swift
    /// try await client.tryAction(.hazardLights)         // flash hazards once
    /// try await client.tryAction(.foldMirrors)          // toggle folded mirrors
    /// try await client.tryAction(.openFrunk)            // pop the frunk
    /// try await client.tryAction(.cabinTemp, states: [22]) // set 22 °C
    /// ```
    ///
    /// - Parameters:
    ///   - action: Which action to emulate.
    ///   - switchType: Press shape. ``SwitchType/toggle`` for a single press
    ///     (default); ``SwitchType/delay(seconds:)`` for long-press emulation.
    ///   - states: Numeric arguments. Must be non-empty - the firmware
    ///     rejects empty state lists with `Status.InvalidArgument`. Defaults
    ///     to `[1]` which works for all toggleable actions.
    ///
    /// - Throws: ``CommanderError`` if the session is not ready or the
    ///   Commander rejects the action.
    @discardableResult
    public func tryAction(
        _ action: TeslaAction,
        switchType: SwitchType = .toggle,
        states: [UInt32] = [1]
    ) async throws -> CommanderStatus {
        guard let sec = sec, let ch = endpoints[S3XYCommander.Endpoint.cmd] else {
            throw CommanderError.notSessionReady
        }
        let plain = ActionBuild.tryAction(action, switchType: switchType, states: states)
        let enc = sec.encrypt(plain)
        logger.info("TryAction \(String(describing: action)) switch=\(String(describing: switchType)) states=\(states)")
        let resp = try await writeAndRead(cmd: enc, on: ch)
        let plainResp = sec.decrypt(resp)
        let (_, status) = try Parse.respStatus(plainResp)
        if status != .success {
            logger.notice("TryAction rejected: \(status.description)")
        }
        return status
    }

    /// Explicitly disconnect and reset state. Safe to call multiple times.
    public func disconnect() {
        if let p = activePeripheral { central?.cancelPeripheralConnection(p) }
        tearDownSession()
    }

    private func tearDownSession() {
        activePeripheral = nil
        endpoints.removeAll()
        sec = nil
        pushCount = 0
        latestDelta = VehicleData()
        accumulated = VehicleData()
        pendingSessionRead = nil
        pendingCmdRead = nil
        currentPhase = .disconnected
    }

    private func publishLatest() {
        let obs = latestObservation
        for (_, c) in vehicleDataContinuations { c.yield(obs) }
    }

    // ─── BLE power-on wait ─────────────────────────────────────
    private var btPowerOnContinuations: [CheckedContinuation<Void, Error>] = []
    private func waitForBluetoothPowerOn() async throws {
        if central.state == .poweredOn { return }
        if central.state == .unauthorized { throw CommanderError.bluetoothUnauthorized }
        if central.state == .unsupported { throw CommanderError.bluetoothUnavailable }
        try await withCheckedThrowingContinuation { cont in
            btPowerOnContinuations.append(cont)
        }
    }

    // ─── Discovery ──────────────────────────────────────────────
    private var discoveryContinuation: CheckedContinuation<Void, Error>?
    private func discover() async throws {
        currentPhase = .discovering
        activePeripheral?.discoverServices([S3XYCommander.serviceUUID])
        try await withCheckedThrowingContinuation { cont in
            self.discoveryContinuation = cont
        }
    }

    // ─── Handshake + Registration ──────────────────────────────
    private func runHandshakeAndRegistration() async throws {
        guard let session = endpoints[S3XYCommander.Endpoint.session],
              let cmd = endpoints[S3XYCommander.Endpoint.cmd],
              endpoints[S3XYCommander.Endpoint.push] != nil else {
            throw CommanderError.endpointsMissing(
                have: Array(endpoints.keys),
                need: [S3XYCommander.Endpoint.session, S3XYCommander.Endpoint.cmd, S3XYCommander.Endpoint.push]
            )
        }
        currentPhase = .handshake

        let sec = Security1(pop: config.pop)
        self.sec = sec
        self.pushPlaintext = config.disablePushEncryption

        // Step 0
        let step0 = sec.makeStep0Request(disablePushEncryption: config.disablePushEncryption)
        let resp0 = try await writeAndRead(cmd: step0, on: session)
        let step1 = try sec.makeStep1Request(fromDeviceStep0: resp0)
        let resp1 = try await writeAndRead(cmd: step1, on: session)
        try sec.verifyStep1(fromDeviceStep1: resp1)

        currentPhase = .registering
        try await sendUUIDWithRetry(on: cmd)
    }

    private func sendUUIDWithRetry(on ch: CBCharacteristic) async throws {
        guard let sec = sec else { throw CommanderError.notSessionReady }
        var attempt = 0
        repeat {
            attempt += 1
            let plain = Build.sendUUID(phoneUUID)
            let enc = sec.encrypt(plain)
            logger.info("SendUUID attempt \(attempt), uuid=\(self.phoneUUID)")
            let resp = try await writeAndRead(cmd: enc, on: ch)
            let plainResp = sec.decrypt(resp)
            let (_, status) = try Parse.respStatus(plainResp)
            if status == .success {
                logger.info("SendUUID OK")
                return
            }
            logger.notice("SendUUID rejected with status=\(status.description)")
            // Not in allowlist → ask host app whether to wait for user to
            // physically authorise via the steering-wheel double-press.
            guard let handler = pairingHandler else {
                throw CommanderError.sendUUIDRejected(
                    status: status,
                    hint: "Pass a `PairingAuthorizationHandler` to connect(…) to drive the physical pairing flow."
                )
            }
            let shouldRetry = await handler.commanderRequestsPhysicalAuthorization()
            guard shouldRetry else {
                throw CommanderError.sendUUIDRejected(status: status, hint: "User declined to authorise.")
            }
            // Give the firmware a moment to pick up the CAN-bus button event.
            try? await Task.sleep(nanoseconds: 500_000_000)
        } while attempt < 10
        throw CommanderError.sendUUIDRejected(status: .invalidArgument, hint: "Exhausted retry attempts.")
    }

    // ─── Low-level BLE write+read ──────────────────────────────
    private func writeAndRead(cmd: Data, on ch: CBCharacteristic) async throws -> Data {
        guard let p = activePeripheral else { throw CommanderError.notConnected }
        return try await withCheckedThrowingContinuation { cont in
            // Decide which pending slot
            if ch.uuid == endpoints[S3XYCommander.Endpoint.session]?.uuid {
                self.pendingSessionRead = { cont.resume(with: $0) }
            } else {
                self.pendingCmdRead = { cont.resume(with: $0) }
            }
            p.writeValue(cmd, for: ch, type: .withResponse)
            // didWriteValueFor will trigger the readValue; see delegates
        }
    }

    // ─── Push handling ─────────────────────────────────────────
    private func handlePush(_ data: Data) {
        pushCount += 1
        let payloadBytes = pushPlaintext ? data : (sec?.decrypt(data) ?? data)
        do {
            if let pvh = try Parse.vehicleDataPushPayload(payloadBytes) {
                let delta = try VehicleDataDecoder.decode(pvh)
                latestDelta = delta
                accumulated = delta.merged(onto: accumulated)
                publishLatest()
            }
        } catch {
            logger.error("push parse error: \(String(describing: error))")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension S3XYCommanderClient: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ c: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.info("central state: \(c.state.rawValue)")
            switch c.state {
            case .poweredOn:
                for cont in self.btPowerOnContinuations { cont.resume() }
                self.btPowerOnContinuations.removeAll()
            case .unauthorized:
                let err = CommanderError.bluetoothUnauthorized
                for cont in self.btPowerOnContinuations { cont.resume(throwing: err) }
                self.btPowerOnContinuations.removeAll()
            case .unsupported, .poweredOff:
                let err = CommanderError.bluetoothUnavailable
                for cont in self.btPowerOnContinuations { cont.resume(throwing: err) }
                self.btPowerOnContinuations.removeAll()
            default: break
            }
        }
    }

    nonisolated public func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                                           advertisementData ad: [String : Any], rssi: NSNumber) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let d = DiscoveredCommander(
                id: p.identifier, name: p.name, rssi: rssi.intValue, peripheral: p
            )
            if self.discoveredByID[p.identifier] == nil {
                self.discoveredByID[p.identifier] = d
                self.scanResults.append(d)
                self.logger.info("discovered \(d.name ?? "<nil>") rssi \(d.rssi)")
            }
        }
    }

    nonisolated public func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        Task { @MainActor [weak self] in
            self?.logger.info("didConnect")
            self?.connectContinuation?.resume()
            self?.connectContinuation = nil
        }
    }
    nonisolated public func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            self?.connectContinuation?.resume(throwing: CommanderError.disconnected(underlying: error))
            self?.connectContinuation = nil
        }
    }
    nonisolated public func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.notice("disconnected")
            // Fail any pending continuations with an error.
            let err = CommanderError.disconnected(underlying: error)
            self.pendingSessionRead?(.failure(err)); self.pendingSessionRead = nil
            self.pendingCmdRead?(.failure(err)); self.pendingCmdRead = nil
            self.connectContinuation?.resume(throwing: err); self.connectContinuation = nil
            self.discoveryContinuation?.resume(throwing: err); self.discoveryContinuation = nil
            self.tearDownSession()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension S3XYCommanderClient: CBPeripheralDelegate {
    nonisolated public func peripheral(_ p: CBPeripheral, didDiscoverServices e: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard e == nil,
                  let svc = p.services?.first(where: { $0.uuid == S3XYCommander.serviceUUID })
                        ?? p.services?.first else {
                self.discoveryContinuation?.resume(throwing: CommanderError.protocolError("no services"))
                self.discoveryContinuation = nil
                return
            }
            p.discoverCharacteristics(nil, for: svc)
        }
    }
    nonisolated public func peripheral(_ p: CBPeripheral,
                                       didDiscoverCharacteristicsFor svc: CBService, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let chars = svc.characteristics, !chars.isEmpty else {
                self.discoveryContinuation?.resume(throwing: CommanderError.protocolError("no chars"))
                self.discoveryContinuation = nil
                return
            }
            self.descsLeft = chars.count
            for ch in chars { p.discoverDescriptors(for: ch) }
        }
    }
    nonisolated public func peripheral(_ p: CBPeripheral,
                                       didDiscoverDescriptorsFor ch: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let d = ch.descriptors?.first(where: { $0.uuid == CBUUID(string: "2901") }) {
                p.readValue(for: d)
            } else {
                self.register(name: "unknown:\(ch.uuid.uuidString.prefix(8))", char: ch)
                self.noteDescReady()
            }
        }
    }
    nonisolated public func peripheral(_ p: CBPeripheral, didUpdateValueFor desc: CBDescriptor, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            var name = "?"
            if let s = desc.value as? String { name = s }
            else if let d = desc.value as? Data, let s = String(data: d, encoding: .utf8) {
                name = s.trimmingCharacters(in: .controlCharacters)
            }
            self.register(name: name, char: desc.characteristic!)
            self.noteDescReady()
        }
    }
    @MainActor private func register(name: String, char: CBCharacteristic) {
        endpoints[name] = char
        logger.debug("endpoint '\(name)' uuid=\(char.uuid)")
    }
    @MainActor private func noteDescReady() {
        descsLeft -= 1
        guard descsLeft <= 0 else { return }
        // Enable notify on push-enhapi if present.
        if let push = endpoints[S3XYCommander.Endpoint.push] {
            activePeripheral?.setNotifyValue(true, for: push)
        }
        // Hand control back to the handshake Task.
        discoveryContinuation?.resume()
        discoveryContinuation = nil
    }

    nonisolated public func peripheral(_ p: CBPeripheral, didWriteValueFor ch: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let e = error {
                let err = CommanderError.protocolError("write to \(ch.uuid): \(e.localizedDescription)")
                self.pendingSessionRead?(.failure(err)); self.pendingSessionRead = nil
                self.pendingCmdRead?(.failure(err)); self.pendingCmdRead = nil
                return
            }
            // Protocomm response-via-read: trigger read on the characteristic we wrote.
            p.readValue(for: ch)
        }
    }

    nonisolated public func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let data = ch.value else { return }
            guard let (name, _) = self.endpoints.first(where: { $0.value === ch }) else { return }
            switch name {
            case S3XYCommander.Endpoint.session:
                self.pendingSessionRead?(.success(data)); self.pendingSessionRead = nil
            case S3XYCommander.Endpoint.cmd:
                self.pendingCmdRead?(.success(data)); self.pendingCmdRead = nil
            case S3XYCommander.Endpoint.push:
                self.handlePush(data)
            default:
                self.logger.debug("read on \(name) ignored")
            }
        }
    }
}
