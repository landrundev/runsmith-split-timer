import Foundation

/// Sent from an assistant coach → host coach after the race ends.
/// Athlete IDs match SharedRaceConfig.athletes[n].id — no name-matching needed.
struct CoachSplitPayload: Codable {
    let version: Int           // Schema version — always 1 for now
    let configId: UUID         // Links back to SharedRaceConfig.configId
    let coachName: String      // Display name of the exporting coach, e.g. "Coach Williams"
    let exportedAt: Date       // Timestamp of export
    let athleteSplits: [AthleteTimingData]

    // Race context (v2 — optional for backward compat with v1 payloads)
    let raceName: String?
    let eventType: String?     // e.g. "800m", "4×400m"
    let meetName: String?
}

/// Split data for a single athlete, keyed by the shared UUID.
/// `splits` is an ordered array of elapsedMs values, one per split ordinal
/// (same ordering as the host's Split entities sorted by lapIndex).
struct AthleteTimingData: Codable {
    let athleteId: UUID   // Matches SharedAthlete.id / host's Athlete.id
    let splits: [Int]     // elapsedMs values in lap order
}
