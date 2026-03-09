import Foundation

/// An assistant coach's split data for every completed race in a meet.
/// Serialized as JSON with a `.runsmith` file extension.
struct CoachMeetPayload: Codable, Identifiable {
    let version: Int              // Schema version — always 1
    let id: UUID                  // Unique import session ID
    let meetId: UUID              // The meet this data belongs to
    let meetName: String          // For display — the meet name at time of export
    let coachName: String         // Assistant coach's display name
    let exportedAt: Date          // Timestamp of export
    let racePayloads: [RacePayloadEntry]
}

/// One race's worth of timing data inside a CoachMeetPayload.
struct RacePayloadEntry: Codable, Identifiable {
    var id: UUID { configId }
    let configId: UUID            // Links to Race.configId for matching
    let raceId: UUID              // The actual Race.id on the exporting device
    let meetId: UUID              // The Meet.id this race belongs to
    let raceName: String          // For display
    let athleteSplits: [AthleteTimingData]
}
