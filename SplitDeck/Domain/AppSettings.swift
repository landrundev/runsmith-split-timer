import Foundation

// MARK: – PaceUnit

enum PaceUnit: String, CaseIterable {
    case perMile = "perMile"
    case perKm   = "perKm"

    var label: String {
        switch self {
        case .perMile: return "/mi"
        case .perKm:   return "/km"
        }
    }

    var metersPerUnit: Double {
        switch self {
        case .perMile: return 1609.34
        case .perKm:   return 1000.0
        }
    }
}

// MARK: – AppSettings

enum AppSettings {

    // MARK: App Mode

    enum AppMode: String {
        case coach     = "coach"
        case spectator = "spectator"
    }

    private static let appModeKey = "runsmith_appMode"

    /// nil means first launch — ModeSelectorView will be shown.
    static var appMode: AppMode? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: appModeKey)
            else { return nil }
            return AppMode(rawValue: raw)
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v.rawValue, forKey: appModeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: appModeKey)
            }
        }
    }

    // MARK: SpectatorChild

    struct SpectatorChild: Codable, Identifiable, Equatable, Hashable {
        let id: UUID            // matches AthleteEntity.id in Core Data
        var displayName: String // "Ava" — what the parent calls them
        var addedAt: Date
    }

    private static let myChildrenKey = "runsmith_myChildren"

    static var myChildren: [SpectatorChild] {
        get {
            guard let data = UserDefaults.standard.data(forKey: myChildrenKey),
                  let decoded = try? JSONDecoder().decode([SpectatorChild].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: myChildrenKey)
            }
        }
    }

    static func addChild(_ child: SpectatorChild) {
        var children = myChildren
        if !children.contains(where: { $0.id == child.id }) {
            children.append(child)
            myChildren = children
        }
    }

    static func removeChild(id: UUID) {
        myChildren = myChildren.filter { $0.id != id }
    }

    static func updateChild(_ child: SpectatorChild) {
        myChildren = myChildren.map { $0.id == child.id ? child : $0 }
    }
}
