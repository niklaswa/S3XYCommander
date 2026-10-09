import Foundation
import CoreBluetooth

/// A Commander found by ``S3XYCommanderClient/scan(timeout:)``.
///
/// Keep this value around to pass it to ``S3XYCommanderClient/connect(to:pairingAuthorizationHandler:)``.
public struct DiscoveredCommander: Sendable, Hashable, Identifiable {
    /// iOS-generated opaque identifier for the physical device.
    /// (CoreBluetooth never exposes the real BLE MAC on iOS/macOS.)
    public let id: UUID
    /// Advertising name, typically `ENH_<last-6-of-mac>` on current firmware.
    public let name: String?
    /// Last observed RSSI in dBm. Negative - closer to 0 is stronger.
    public let rssi: Int

    /// Reference to the live CoreBluetooth peripheral. The library needs this
    /// to actually connect; apps may read `.state`/`.name` from it if useful.
    public let peripheral: CBPeripheral

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
