import Foundation

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
