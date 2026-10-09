import Foundation

/// Errors emitted by ``S3XYCommanderClient``.
public enum CommanderError: Error, CustomStringConvertible {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case notConnected
    case notSessionReady
    case endpointsMissing(have: [String], need: [String])
    case handshakeFailed(String)
    case sendUUIDRejected(status: CommanderStatus, hint: String)
    case subscribeRejected(status: CommanderStatus)
    case disconnected(underlying: Error?)
    case protocolError(String)
    case timeout(String)

    public var description: String {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth not powered on or not available on this device."
        case .bluetoothUnauthorized:
            return "App is not authorized to use Bluetooth. Add NSBluetoothAlwaysUsageDescription to Info.plist and have the user allow it."
        case .notConnected:
            return "Not connected to a Commander."
        case .notSessionReady:
            return "The Security1 session is not up yet."
        case .endpointsMissing(let have, let need):
            return "Required GATT endpoints missing. Have: \(have.sorted().joined(separator: ", ")). Need: \(need.joined(separator: ", "))."
        case .handshakeFailed(let m):
            return "Handshake failed: \(m)"
        case .sendUUIDRejected(let s, let hint):
            return "Commander rejected SendUUID with status=\(s). \(hint)"
        case .subscribeRejected(let s):
            return "Commander rejected Subscribe with status=\(s)."
        case .disconnected(let u):
            if let u = u { return "Disconnected: \(u.localizedDescription)" }
            return "Disconnected."
        case .protocolError(let m):
            return "Protocol error: \(m)"
        case .timeout(let what):
            return "Timed out: \(what)."
        }
    }
}
