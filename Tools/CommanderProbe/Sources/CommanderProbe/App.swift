import S3XYCommander
import SwiftUI

@main
struct CommanderProbeApp: App {
    @State private var probe = Probe(logFolder: Self.logFolder)

    /// `--logs <folder>` from run.sh; otherwise next to the app.
    private static var logFolder: URL {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--logs"), index + 1 < arguments.count {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return Bundle.main.bundleURL.deletingLastPathComponent().appending(path: "logs", directoryHint: .isDirectory)
    }

    var body: some Scene {
        WindowGroup("Commander Probe") {
            ProbeView()
                .environment(probe)
                .frame(minWidth: 900, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    probe.disconnect()
                }
        }
    }
}

struct ProbeView: View {
    @Environment(Probe.self) private var probe
    @State private var tab = Tab.navigation
    @State private var filter = ""
    @State private var noteText = ""

    enum Tab: String, CaseIterable, Identifiable {
        case navigation = "Navigation & Medien", vehicle = "Alle Fahrzeugdaten", events = "Lenkrad-Events"
        case pushes = "Andere Pushes", answers = "Antworten & Notizen", tesla = "Tesla-API"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if probe.awaitingPairing { pairingBanner }
            if let error = probe.lastError {
                Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                TextField("Notiz ins Log, z. B. „Route nach Köln im Tesla gestartet“", text: $noteText)
                    .onSubmit(addNote)
                Button("Markieren", action: addNote).disabled(noteText.isEmpty)
            }
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            content
        }
        .padding(14)
        // In the car: start the app, and it looks for the Commander right away.
        .task { await probe.connect() }
    }

    private func addNote() {
        probe.note(noteText)
        noteText = ""
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(probe.phase == "empfange" ? .green : .orange).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(probe.deviceName ?? "S3XY Commander").font(.headline)
                Text("\(probe.phase) · \(probe.pushCount) Pushes · Mac-ID \(probe.phoneUUID)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            Button("Verbinden") { Task { await probe.connect() } }
                .disabled(probe.busy || probe.phase == "empfange")
            Button("Trennen") { probe.disconnect() }
            Menu("Abfragen") {
                Button("Tesla-API-Status") { Task { await probe.queryTeslaAPI() } }
                Divider()
                ForEach(Schema.getRequests) { request in
                    Button(request.name) { Task { await probe.send(request) } }
                }
            }
            .fixedSize()
            Menu("Abonnieren") {
                Button("Alles") { Task { await probe.subscribe(nil) } }
                Button("Nur Navigation (1–10)") { Task { await probe.subscribe(Array(1...10)) } }
                Button("Navigation + Medien (1–23)") { Task { await probe.subscribe(Array(1...23)) } }
                Button("Lenkrad-Events") { Task { await probe.subscribeEvents() } }
            }
            .fixedSize()
            Button("Logs") { probe.revealLogs() }
        }
    }

    private var pairingBanner: some View {
        HStack {
            Image(systemName: "steeringwheel").font(.title)
            Text("Der Commander kennt diesen Mac noch nicht: im Auto das **rechte Scrollrad doppelt drücken**, dann „Gedrückt“.")
            Spacer()
            Button("Gedrückt") { probe.answerPairing(true) }.keyboardShortcut(.defaultAction)
            Button("Abbrechen") { probe.answerPairing(false) }
        }
        .padding(10)
        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .navigation:
            FieldTable(rows: probe.vehicle.values.filter { $0.number <= 23 }, filter: "")
            Text("Kommen hier keine Werte, obwohl im Tesla eine Route läuft: Tab „Tesla-API“ zeigt, ob der Commander mit der Fahrzeug-API verbunden ist.")
                .font(.caption).foregroundStyle(.secondary)
        case .vehicle:
            TextField("Filter (Name oder Nummer)", text: $filter)
            FieldTable(rows: Array(probe.vehicle.values), filter: filter)
        case .events:
            FieldTable(rows: Array(probe.events.values), filter: "")
            Text("Scrollräder drücken, kippen, drehen: jede Änderung erscheint hier.").font(.caption).foregroundStyle(.secondary)
        case .pushes:
            VStack(alignment: .leading) {
                Text(probe.pushTypes.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    .font(.caption).textSelection(.enabled)
                LogList(lines: probe.otherPushes)
            }
        case .answers:
            LogList(lines: probe.answers)
        case .tesla:
            ScrollView {
                Text(probe.teslaAPI ?? "Noch nicht abgefragt: Abfragen › Tesla-API-Status.")
                    .font(.body.monospaced()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The fields with their values; a value that changed in the last two seconds shows orange.
struct FieldTable: View {
    var rows: [FieldRow]
    var filter: String

    private var shown: [FieldRow] {
        rows.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || String($0.number) == filter }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Table(shown) {
                TableColumn("#") { Text(String($0.number)).monospacedDigit() }.width(36)
                TableColumn("Feld") { Text($0.name).textSelection(.enabled) }.width(min: 180, ideal: 260)
                TableColumn("Wert") { row in
                    Text(row.value)
                        .foregroundStyle(context.date.timeIntervalSince(row.lastChange) < 2 && row.changes > 0 ? .orange : .primary)
                        .textSelection(.enabled)
                }
                .width(min: 160, ideal: 260)
                TableColumn("Änderungen") { Text(String($0.changes)).monospacedDigit() }.width(80)
                TableColumn("Zuletzt") { row in
                    Text("vor \(Int(context.date.timeIntervalSince(row.lastChange))) s").monospacedDigit()
                }
                .width(70)
                TableColumn("Vorher") { Text($0.history.prefix(4).joined(separator: " ← ")).foregroundStyle(.secondary) }
            }
        }
    }
}

struct LogList: View {
    var lines: [LogLine]

    var body: some View {
        List(lines) { line in
            VStack(alignment: .leading, spacing: 2) {
                Text("\(line.date.formatted(date: .omitted, time: .standard))  \(line.title)").font(.headline)
                Text(line.body).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
    }
}
