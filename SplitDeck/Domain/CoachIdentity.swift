import Foundation

enum CoachIdentity {
    private static let key = "runsmith_coachName"

    static var name: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var hasName: Bool { name?.isEmpty == false }
}
