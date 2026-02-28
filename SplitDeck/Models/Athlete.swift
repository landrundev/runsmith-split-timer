import Foundation

struct Athlete: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var teamName: String?
    var colorHex: String // e.g. "#FF3B30"
    var notes: String?

    init(id: UUID = UUID(), name: String, teamName: String? = nil, colorHex: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.teamName = teamName
        self.colorHex = colorHex
        self.notes = notes
    }
}
