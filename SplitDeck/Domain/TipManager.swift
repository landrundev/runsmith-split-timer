import Foundation

/// Tracks which contextual tips have been shown.
/// Each tip is shown once, then permanently dismissed via UserDefaults.
enum TipManager {
    private static let prefix = "runsmith_tip_"

    /// Returns true if the tip has NOT been shown yet (i.e. should display).
    static func shouldShow(_ tipId: String) -> Bool {
        !UserDefaults.standard.bool(forKey: prefix + tipId)
    }

    /// Marks a tip as shown so it never appears again.
    static func markShown(_ tipId: String) {
        UserDefaults.standard.set(true, forKey: prefix + tipId)
    }

    /// Resets all tips (useful for testing only — not exposed in UI).
    static func resetAll() {
        let ids = ["quickRace", "markSplit", "swipeActions", "coachMerge", "relayTiming"]
        for id in ids {
            UserDefaults.standard.removeObject(forKey: prefix + id)
        }
    }
}
