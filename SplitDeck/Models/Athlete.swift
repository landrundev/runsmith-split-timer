import Foundation

enum Gender: String, Codable, CaseIterable {
    case male = "M"
    case female = "F"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

struct Athlete: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var teamName: String?
    var colorHex: String // e.g. "#FF3B30"
    var notes: String?
    var gender: Gender
    var isArchived: Bool

    init(id: UUID = UUID(), name: String, teamName: String? = nil, colorHex: String, notes: String? = nil, gender: Gender, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.teamName = teamName
        self.colorHex = colorHex
        self.notes = notes
        self.gender = gender
        self.isArchived = isArchived
    }
}
