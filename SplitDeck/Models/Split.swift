import Foundation

struct Split: Identifiable, Codable, Hashable {
    let id: UUID
    let raceId: UUID
    let athleteId: UUID
    let lapIndex: Int  // 1-based
    let elapsedMs: Int // milliseconds from race startedAt

    init(id: UUID = UUID(), raceId: UUID, athleteId: UUID, lapIndex: Int, elapsedMs: Int) {
        self.id = id
        self.raceId = raceId
        self.athleteId = athleteId
        self.lapIndex = lapIndex
        self.elapsedMs = elapsedMs
    }
}
