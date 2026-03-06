import Foundation

enum EventType: Int16, Codable, CaseIterable {
    case m800 = 0
    case m1600 = 1
    case m3200 = 2
    case custom = 3
    case relay4x400  = 4
    case relay4x800  = 5
    case relay4x1600 = 6
    case relay4x3200 = 7
    case m400   = 8
    case m1500  = 9
    case m5000  = 10
    case m10000 = 11
    case mile   = 12

    var displayName: String {
        switch self {
        case .m400:      return "400m"
        case .m800:      return "800m"
        case .m1500:     return "1500m"
        case .mile:      return "Mile"
        case .m1600:     return "1600m"
        case .m3200:     return "3200m"
        case .m5000:     return "5000m"
        case .m10000:    return "10000m"
        case .custom:    return "Custom"
        case .relay4x400:  return "4\u{00D7}400m"
        case .relay4x800:  return "4\u{00D7}800m"
        case .relay4x1600: return "4\u{00D7}1600m"
        case .relay4x3200: return "4\u{00D7}3200m"
        }
    }

    var isRelay: Bool {
        switch self {
        case .relay4x400, .relay4x800, .relay4x1600, .relay4x3200: return true
        default: return false
        }
    }

    /// Distance per relay leg. nil for individual events.
    var legDistanceMeters: Int? {
        switch self {
        case .relay4x400:  return 400
        case .relay4x800:  return 800
        case .relay4x1600: return 1600
        case .relay4x3200: return 3200
        default:           return nil
        }
    }

    var defaultDistance: Int? {
        switch self {
        case .m400:   return 400
        case .m800:   return 800
        case .m1500:  return 1500
        case .mile:   return 1609
        case .m1600:  return 1600
        case .m3200:  return 3200
        case .m5000:  return 5000
        case .m10000: return 10000
        case .custom: return nil
        default:      return legDistanceMeters
        }
    }
}

enum RaceStatus: Int16, Codable {
    case notStarted = 0
    case inProgress = 1
    case completed = 2

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        }
    }
}

struct Race: Identifiable, Codable, Hashable {
    let id: UUID
    var meetId: UUID?           // nil for Quick Race
    var configId: UUID?         // links to SharedRaceConfig.configId for merge validation
    var name: String            // e.g. "Boys 1600m – Heat 1"
    var eventType: EventType
    var distanceMeters: Int
    var trackLengthMeters: Int  // MVP: always 400 (or legDistance for relay)
    var splitsPerLap: Int       // MVP: always 1
    var isUnlimitedSplits: Bool // true = no predetermined lap count
    var athleteIds: [UUID]      // display order; leg order for relay
    var startedAt: Date?        // stored as UTC; never convert for calculations
    var endedAt: Date?
    var status: RaceStatus
    var isArchived: Bool
    var isMerged: Bool

    // Computed — never stored
    var laps: Int {
        guard !isUnlimitedSplits else { return Int.max }
        return Int(ceil(Double(distanceMeters) / Double(trackLengthMeters)))
    }

    var expectedSplitsPerAthlete: Int {
        guard !isUnlimitedSplits else { return Int.max }
        return laps * splitsPerLap
    }

    init(
        id: UUID = UUID(),
        meetId: UUID? = nil,
        configId: UUID? = nil,
        name: String,
        eventType: EventType,
        distanceMeters: Int,
        trackLengthMeters: Int = 400,
        splitsPerLap: Int = 1,
        isUnlimitedSplits: Bool = false,
        athleteIds: [UUID] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        status: RaceStatus = .notStarted,
        isArchived: Bool = false,
        isMerged: Bool = false
    ) {
        self.id = id
        self.meetId = meetId
        self.configId = configId
        self.name = name
        self.eventType = eventType
        self.distanceMeters = distanceMeters
        self.trackLengthMeters = trackLengthMeters
        self.splitsPerLap = splitsPerLap
        self.isUnlimitedSplits = isUnlimitedSplits
        self.athleteIds = athleteIds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.isArchived = isArchived
        self.isMerged = isMerged
    }
}
