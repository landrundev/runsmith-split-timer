import Foundation

struct Meet: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var location: String?

    init(id: UUID = UUID(), name: String, date: Date, location: String? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
    }
}
