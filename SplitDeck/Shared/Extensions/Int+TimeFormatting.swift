import Foundation

extension Int {
    /// Formats elapsedMs as M:SS.cc (centiseconds)
    /// e.g. 288930ms → "4:48.93"
    var formattedSplitTime: String {
        let totalCs = self / 10
        let cs = totalCs % 100
        let totalS = totalCs / 100
        let secs = totalS % 60
        let mins = totalS / 60
        return String(format: "%d:%02d.%02d", mins, secs, cs)
    }
}
