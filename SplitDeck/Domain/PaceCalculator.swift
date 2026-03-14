import Foundation

enum PaceCalculator {

    /// Formats a lap split into a pace string, e.g. "5:12/mi".
    /// - Parameters:
    ///   - lapMs: elapsed milliseconds for the lap
    ///   - lapMeters: distance of the lap in meters
    ///   - unit: desired pace unit (per-mile or per-km)
    /// - Returns: Formatted pace string, or nil if inputs are invalid.
    static func format(lapMs: Int, lapMeters: Int, unit: PaceUnit = .perMile) -> String? {
        guard lapMs > 0, lapMeters > 0 else { return nil }

        let secondsPerMeter = Double(lapMs) / 1000.0 / Double(lapMeters)
        let paceSeconds = secondsPerMeter * unit.metersPerUnit

        let mins = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d%@", mins, secs, unit.label)
    }
}
