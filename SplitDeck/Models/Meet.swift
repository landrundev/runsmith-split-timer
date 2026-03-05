import Foundation

struct Meet: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var location: String?
    var isArchived: Bool

    init(id: UUID = UUID(), name: String, date: Date, location: String? = nil, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
        self.isArchived = isArchived
    }
}
