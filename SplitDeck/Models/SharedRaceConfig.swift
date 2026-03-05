import Foundation

/// Shared from host coach → assistant coaches before the race starts.
/// Contains the full race setup and athlete list with stable UUIDs.
struct SharedRaceConfig: Codable {
    let version: Int           // Schema version — always 1 for now
    let configId: UUID         // Unique ID linking this config to its CoachSplitPayloads
    let hostCoachName: String  // Display name of the host coach, e.g. "Coach Davis"

    // Race configuration
    let raceName: String
    let eventType: EventType
    let distanceMeters: Int
    let trackLengthMeters: Int
    let splitsPerLap: Int
    let isUnlimitedSplits: Bool

    // Athlete list — UUIDs must match the host's Core Data athlete IDs
    let athletes: [SharedAthlete]
}

/// A lightweight athlete record for embedding in SharedRaceConfig.
/// The `id` is the host's canonical UUID for this athlete — assistant coaches
/// use it to create a matching local athlete so post-race split payloads
/// can be merged by UUID without any name-matching.
struct SharedAthlete: Codable, Identifiable {
    let id: UUID
    let name: String
    let gender: Gender?
    let colorHex: String
}
