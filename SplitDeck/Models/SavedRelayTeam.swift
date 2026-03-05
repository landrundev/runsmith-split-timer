import Foundation

struct SavedRelayTeam: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var eventType: EventType
    var gender: Gender
    var athleteIds: [UUID] // ordered by leg
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        eventType: EventType,
        gender: Gender,
        athleteIds: [UUID],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.eventType = eventType
        self.gender = gender
        self.athleteIds = athleteIds
        self.createdAt = createdAt
    }
}
