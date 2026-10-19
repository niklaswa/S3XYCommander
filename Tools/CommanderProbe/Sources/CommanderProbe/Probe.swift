import AppKit
import Foundation
import Observation
import S3XYCommander

/// One field the Commander reported, with what it did over the session.
struct FieldRow: Identifiable {
    let number: UInt64
    let name: String
    var value: String
    var changes = 0
    var firstSeen: Date
    var lastChange: Date
    /// Earlier values, newest first.
    var history: [String] = []
    var id: UInt64 { number }
}

/// A push other than vehicle data, or an answer to a request.
struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let body: String
}

/// Connects to the Commander, listens to everything it sends and writes it all down: every push
/// raw and decoded into `logs/session-….jsonl`, the current state into `latest-state.json`.
@MainActor
@Observable
final class Probe: PairingAuthorizationHandler {
    private(set) var phase = "getrennt"
    private(set) var deviceName: String?
    private(set) var pushCount = 0
    private(set) var pushTypes: [String: Int] = [:]
    private(set) var vehicle: [UInt64: FieldRow] = [:]
    private(set) var events: [UInt64: FieldRow] = [:]
    private(set) var otherPushes: [LogLine] = []
    private(set) var answers: [LogLine] = []
    private(set) var teslaAPI: String?
    private(set) var awaitingPairing = false
    private(set) var busy = false
    private(set) var lastError: String?
    let logFolder: URL

    @ObservationIgnored private let client = S3XYCommanderClient(config: {
        var config = S3XYCommanderClient.Config()
        config.logSubsystem = "top.niklas.commanderprobe"
        return config
    }())
    @ObservationIgnored private var pairingContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var log: FileHandle?
    @ObservationIgnored private var observing: Task<Void, Never>?
    @ObservationIgnored private var snapshotTimer: Timer?

    init(logFolder: URL) {
        self.logFolder = logFolder
        try? FileManager.default.createDirectory(at: logFolder, withIntermediateDirectories: true)
        client.onRawPush = { [weak self] data in self?.handle(push: data) }
        observing = Task { [weak self] in
            guard let stream = self?.client.vehicleData else { return }
            for await observation in stream {
                self?.phase = Self.label(observation.phase)
                self?.deviceName = observation.deviceName ?? self?.deviceName
            }
        }
    }

    var phoneUUID: String { client.phoneUUID }

    // MARK: Connecting

    func connect() async {
        busy = true; lastError = nil
        defer { busy = false }
        openLog()
        write(["dir": "app", "event": "connect", "phoneUUID": client.phoneUUID])
        do {
            let found = try await client.scan(timeout: 8)
            write(["dir": "app", "event": "scan", "found": found.map { "\($0.name ?? "?") \($0.rssi) dBm" }])
            guard let commander = found.max(by: { $0.rssi < $1.rssi }) else {
                phase = "kein Commander gefunden"
                lastError = "Keiner in Reichweite. Er nimmt nur eine Verbindung an: Bluetooth am iPhone aus oder Monav und die S3XY-App schließen."
                return
            }
            deviceName = commander.name
            try await client.connect(to: commander, pairingAuthorizationHandler: self)
            // First: whether the Commander talks to the car's API at all — nav and media depend on it.
            await queryTeslaAPI()
            try await client.subscribeAll()
            await subscribeEvents()
            startSnapshots()
        } catch {
            fail(error)
        }
    }

    func disconnect() {
        client.disconnect()
        snapshotTimer?.invalidate()
        writeSnapshot()
        write(["dir": "app", "event": "disconnect"])
        phase = "getrennt"
    }

    /// The Commander does not know this Mac yet: the right scroll wheel has to say yes.
    nonisolated func commanderRequestsPhysicalAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.pairingContinuation = continuation
                self.awaitingPairing = true
                self.write(["dir": "app", "event": "pairing requested"])
            }
        }
    }

    func answerPairing(_ pressed: Bool) {
        awaitingPairing = false
        pairingContinuation?.resume(returning: pressed)
        pairingContinuation = nil
    }

    // MARK: Requests

    /// What the Commander's own link to the car's API is doing (Enhauto's "Tesla API" add-on).
    func queryTeslaAPI() async {
        guard let request = Schema.getRequests.first(where: { $0.name == "ReqGetApiStatus" }),
              let answer = await send(request) else { return }
        // EnhApiPayloadHolder field 94: RespGetApiStatus.
        guard let body = Wire.fields(answer)?.first(where: { $0.number == 94 })?.bytes,
              let fields = Wire.fields(body) else {
            teslaAPI = "keine Antwort: " + Wire.describe(answer)
            return
        }
        func label(_ number: UInt64, _ enumName: String) -> String? {
            fields.first { $0.number == number }.map { Wire.render($0, as: .enumeration(enumName)) }
        }
        let sessions = fields.filter { $0.number == 3 }.compactMap { Wire.fields($0.bytes) }.map { session -> String in
            func value(_ n: UInt64, _ e: String) -> String {
                session.first { $0.number == n }.map { Wire.render($0, as: .enumeration(e)) } ?? "–"
            }
            return "\(value(1, "TeslaAPI.SessionDomain")): \(value(2, "TeslaAPI.SessionStatus")), \(value(3, "TeslaAPI.SessionErrorState"))"
        }
        let keys = fields.first { $0.number == 4 }?.varint ?? 0
        let connected = fields.first { $0.number == 5 }?.varint ?? 0
        teslaAPI = [
            "Status: " + (label(1, "TeslaAPI.Status") ?? "TAPIS_Initial (0)"),
            "Fehler: " + (label(2, "TeslaAPI.ErrorState") ?? "TAPIES_NoError (0)"),
            "Kopplung: " + (label(6, "TeslaAPI.UIStatus") ?? "TAPIUIS_NotPaired (0)"),
            "BLE-Schlüssel: \(keys), verbunden: \(connected)",
        ].joined(separator: "\n") + (sessions.isEmpty ? "\nSitzungen: keine" : "\nSitzungen:\n  " + sessions.joined(separator: "\n  "))
    }

    /// A read-only request; the answer goes to the list and the log.
    @discardableResult
    func send(_ request: GetRequest) async -> Data? {
        let plain = Wire.request(msgType: request.msgType, payloadField: request.payloadField)
        do {
            let answer = try await client.sendRawCommand(plain)
            let decoded = Wire.describe(answer)
            answers.insert(LogLine(date: .now, title: request.name, body: decoded), at: 0)
            write(["dir": "answer", "request": request.name, "hex": Wire.hex(answer), "decoded": decoded])
            return answer
        } catch {
            fail(error)
            return nil
        }
    }

    /// Subscribes again: everything, or only these fields — to see whether the Commander sends
    /// some only when asked for them.
    func subscribe(_ numbers: [UInt64]?) async {
        do {
            try await client.subscribeAll(fields: numbers?.compactMap(VehicleSignal.init(rawValue:)))
            write(["dir": "app", "event": "subscribe", "fields": numbers.map { $0.map(String.init) } ?? ["all"]])
        } catch {
            fail(error)
        }
    }

    /// The steering wheel's scroll wheels: `ReqSubscribeVehicleEventsData { subscribe_all }`.
    func subscribeEvents() async {
        let plain = Wire.request(msgType: 152, payloadField: 163, body: Wire.uint(1, 1))
        do {
            let answer = try await client.sendRawCommand(plain)
            write(["dir": "answer", "request": "ReqSubscribeVehicleEventsData", "hex": Wire.hex(answer),
                   "decoded": Wire.describe(answer)])
        } catch {
            fail(error)
        }
    }

    // MARK: Pushes

    private func handle(push data: Data) {
        pushCount += 1
        guard let fields = Wire.fields(data) else {
            write(["dir": "push", "malformed": true, "hex": Wire.hex(data)])
            return
        }
        let type = fields.first { $0.number == 1 }?.varint ?? 0
        let typeName = Schema.enums["EnhApiPushType"]?[type] ?? "push \(type)"
        pushTypes[typeName, default: 0] += 1
        let payload = fields.first { $0.wire == 2 }
        var decoded: [String: String] = [:]

        switch type {
        case 16 where payload != nil: // PushVehicleDataHolder
            decoded = apply(payload!.bytes, schema: Schema.vehicleData, to: &vehicle)
        case 19 where payload != nil: // PushVehicleEventsDataHolder
            decoded = apply(payload!.bytes, schema: Schema.vehicleEvents, to: &events)
        default:
            let body = payload.map { Wire.describe($0.bytes) } ?? "{}"
            otherPushes.insert(LogLine(date: .now, title: typeName, body: body), at: 0)
            if otherPushes.count > 200 { otherPushes.removeLast() }
            decoded = ["payload": body]
            if [12, 13, 23].contains(type) { Task { await queryTeslaAPI() } }
        }
        write(["dir": "push", "type": typeName, "hex": Wire.hex(data), "fields": decoded])
    }

    private func apply(_ body: Data, schema: [UInt64: FieldInfo], to rows: inout [UInt64: FieldRow]) -> [String: String] {
        var decoded: [String: String] = [:]
        for field in Wire.fields(body) ?? [] {
            let info = schema[field.number]
            let name = info?.name ?? "unbekannt_\(field.number)"
            let value = Wire.render(field, as: info?.type)
            decoded[name] = value
            let now = Date.now
            if var row = rows[field.number] {
                if row.value != value {
                    row.history.insert(row.value, at: 0)
                    if row.history.count > 30 { row.history.removeLast() }
                    row.value = value
                    row.changes += 1
                    row.lastChange = now
                }
                rows[field.number] = row
            } else {
                rows[field.number] = FieldRow(number: field.number, name: name, value: value, firstSeen: now, lastChange: now)
            }
        }
        return decoded
    }

    // MARK: Log

    /// A line of the user's own in the log: "Route nach Köln gestartet".
    func note(_ text: String) {
        guard !text.isEmpty else { return }
        write(["dir": "note", "text": text])
        answers.insert(LogLine(date: .now, title: "Notiz", body: text), at: 0)
    }

    private func openLog() {
        guard log == nil else { return }
        let stamp = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.omitted).time(includingFractionalSeconds: false).timeSeparator(.omitted))
        let url = logFolder.appending(path: "session-\(stamp).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        log = try? FileHandle(forWritingTo: url)
    }

    private func write(_ entry: [String: Any]) {
        var entry = entry
        entry["t"] = Date.now.formatted(.iso8601.time(includingFractionalSeconds: true))
        guard let log, JSONSerialization.isValidJSONObject(entry),
              var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        try? log.write(contentsOf: line)
    }

    private func startSnapshots() {
        snapshotTimer?.invalidate()
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.writeSnapshot() }
        }
    }

    /// Everything as it is now, for reading after the drive.
    func writeSnapshot() {
        func rows(_ rows: [UInt64: FieldRow]) -> [[String: Any]] {
            rows.values.sorted { $0.number < $1.number }.map {
                ["field": $0.number, "name": $0.name, "value": $0.value, "changes": $0.changes,
                 "lastChange": $0.lastChange.formatted(.iso8601.time(includingFractionalSeconds: false)),
                 "history": $0.history]
            }
        }
        let snapshot: [String: Any] = [
            "at": Date.now.formatted(.iso8601), "device": deviceName ?? "", "phase": phase,
            "pushes": pushCount, "pushTypes": pushTypes, "teslaAPI": teslaAPI ?? "",
            "vehicle": rows(vehicle), "events": rows(events),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: logFolder.appending(path: "latest-state.json"), options: .atomic)
    }

    func revealLogs() { NSWorkspace.shared.activateFileViewerSelecting([logFolder]) }

    private func fail(_ error: Error) {
        lastError = String(describing: error)
        write(["dir": "app", "error": String(describing: error)])
    }

    private static func label(_ phase: CommanderPhase) -> String {
        switch phase {
        case .idle: "bereit"
        case .scanning: "suche Commander …"
        case .connecting: "verbinde …"
        case .discovering: "lese Dienste …"
        case .handshake: "Handshake …"
        case .registering: "melde Mac an …"
        case .subscribing: "abonniere …"
        case .streaming: "empfange"
        case .disconnected: "getrennt"
        case .failed(let reason): "Fehler: \(reason)"
        }
    }
}
