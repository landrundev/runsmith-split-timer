import Foundation

struct UnassignedMark: Identifiable, Codable, Hashable {
    let id: UUID
    let raceId: UUID
    let timestampMs: Int // elapsed ms from race startedAt
    let createdAt: Date

    init(id: UUID = UUID(), raceId: UUID, timestampMs: Int, createdAt: Date = Date()) {
        self.id = id
        self.raceId = raceId
        self.timestampMs = timestampMs
        self.createdAt = createdAt
    }
}
