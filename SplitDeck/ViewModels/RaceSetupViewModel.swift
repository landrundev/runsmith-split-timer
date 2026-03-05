import Foundation

enum RaceTypeSelection: String, CaseIterable {
    case individual = "Individual"
    case relay = "Relay"
}

@MainActor
final class RaceSetupViewModel: ObservableObject {

    // Form fields
    @Published var raceName: String = ""
    @Published var eventType: EventType = .m1600
    @Published var customDistance: String = ""
    @Published var selectedAthleteIds: Set<UUID> = []
    @Published var athleteSearchText: String = ""
    @Published var genderFilter: Gender? = nil
    @Published var raceType: RaceTypeSelection = .individual {
        didSet {
            guard raceType != oldValue else { return }
            raceName = "" // clear name whenever type changes
            switch raceType {
            case .individual:
                eventType = .m1600
                selectedAthleteIds = []
                // relayAthleteOrder intentionally preserved — restored if user switches back
            case .relay:
                eventType = .relay4x400
                // restore relay selection from preserved order
                selectedAthleteIds = Set(relayAthleteOrder)
            }
        }
    }
    @Published var relayAthleteOrder: [UUID] = [] // leg-ordered athlete IDs for relay
    @Published var unlimitedSplits: Bool = false
    @Published var splitsPerLap: Int = 1

    // Athlete creation
    @Published var newAthleteName: String = ""
    @Published var newAthleteTeam: String = ""
    @Published var newAthleteGender: Gender? = nil

    @Published var errorMessage: String?

    @Published private(set) var availableAthletes: [Athlete] = []
    @Published private(set) var savedRelayTeams: [SavedRelayTeam] = []
    let meetId: UUID?
    let store: SplitDeckStore

    // Predefined athlete colors assigned in rotation
    static let colorPalette = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#007AFF", "#5856D6", "#FF2D55",
        "#AF52DE", "#A2845E"
    ]

    static let maxIndividualAthletes = 50
    static let individualEventTypes: [EventType] = [
        .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000, .custom
    ]
    static let relayEventTypes: [EventType] = [.relay4x400, .relay4x800, .relay4x1600, .relay4x3200]

    init(meetId: UUID?, store: SplitDeckStore) {
        self.meetId = meetId
        self.store = store
    }

    func load() {
        do {
            availableAthletes = try store.fetchAthletes()
            savedRelayTeams = try store.fetchSavedRelayTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Derived

    var filteredAthletes: [Athlete] {
        var result = availableAthletes
        if let gender = genderFilter {
            result = result.filter { $0.gender == gender }
        }
        if !athleteSearchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(athleteSearchText)
            }
        }
        return result
    }

    /// Athletes in relay leg order (ordered by relayAthleteOrder, not alpha)
    var relayAthletesOrdered: [Athlete] {
        relayAthleteOrder.compactMap { id in availableAthletes.first { $0.id == id } }
    }

    var isValid: Bool {
        if eventType.isRelay {
            return relayAthleteOrder.count == 4
        }
        if unlimitedSplits {
            return !selectedAthleteIds.isEmpty
        }
        return distanceMeters > 0 && !selectedAthleteIds.isEmpty
    }

    var distanceMeters: Int {
        if eventType == .custom { return Int(customDistance) ?? 0 }
        return eventType.defaultDistance ?? eventType.legDistanceMeters ?? 0
    }

    var matchingSavedTeams: [SavedRelayTeam] {
        savedRelayTeams.filter { $0.eventType == eventType }
    }

    func loadSavedTeam(_ team: SavedRelayTeam) {
        eventType = team.eventType
        relayAthleteOrder = team.athleteIds.filter { id in
            availableAthletes.contains { $0.id == id }
        }
        selectedAthleteIds = Set(relayAthleteOrder)
    }

    func athlete(for id: UUID) -> Athlete? {
        availableAthletes.first { $0.id == id }
    }

    // MARK: – Athlete selection

    var isAthleteCapReached: Bool {
        if eventType.isRelay { return relayAthleteOrder.count >= 4 }
        return selectedAthleteIds.count >= Self.maxIndividualAthletes
    }

    func toggleAthlete(_ id: UUID) {
        if selectedAthleteIds.contains(id) {
            selectedAthleteIds.remove(id)
            relayAthleteOrder.removeAll { $0 == id }
        } else {
            if eventType.isRelay && relayAthleteOrder.count >= 4 { return }
            if !eventType.isRelay && selectedAthleteIds.count >= Self.maxIndividualAthletes { return }
            selectedAthleteIds.insert(id)
            if eventType.isRelay { relayAthleteOrder.append(id) }
        }
    }

    // MARK: – Reordering

    func moveAthletes(from source: IndexSet, to destination: Int) {
        availableAthletes.move(fromOffsets: source, toOffset: destination)
    }

    func moveRelayLeg(from source: IndexSet, to destination: Int) {
        relayAthleteOrder.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: – Athlete CRUD

    @discardableResult
    func addNewAthlete() -> Athlete? {
        let trimmed = newAthleteName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let color = Self.colorPalette[availableAthletes.count % Self.colorPalette.count]
        let athlete = Athlete(
            name: trimmed,
            teamName: newAthleteTeam.isEmpty ? nil : newAthleteTeam,
            colorHex: color,
            gender: newAthleteGender
        )
        do {
            try store.save(athlete)
            availableAthletes = (try? store.fetchAthletes()) ?? availableAthletes
            toggleAthlete(athlete.id)
            newAthleteName = ""
            newAthleteTeam = ""
            newAthleteGender = nil
            return athlete
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func update(athlete: Athlete, name: String, teamName: String, colorHex: String, gender: Gender?) {
        let updated = Athlete(
            id: athlete.id,
            name: name.trimmingCharacters(in: .whitespaces),
            teamName: teamName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : teamName,
            colorHex: colorHex,
            notes: athlete.notes,
            gender: gender
        )
        do {
            try store.save(updated)
            availableAthletes = (try? store.fetchAthletes()) ?? availableAthletes
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(athlete: Athlete) {
        do {
            try store.delete(athleteId: athlete.id)
            selectedAthleteIds.remove(athlete.id)
            relayAthleteOrder.removeAll { $0 == athlete.id }
            availableAthletes = (try? store.fetchAthletes()) ?? availableAthletes
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Start Race

    func startRace() -> Race? {
        guard isValid else { return nil }

        let orderedIds: [UUID]
        let dist: Int
        let track: Int

        if eventType.isRelay {
            orderedIds = relayAthleteOrder
            let legDist = eventType.legDistanceMeters!
            dist  = legDist
            track = legDist // laps = 1 per relay athlete
        } else {
            orderedIds = availableAthletes
                .filter { selectedAthleteIds.contains($0.id) }
                .map(\.id)
            dist  = distanceMeters
            track = 400
        }

        let name = raceName.isEmpty
            ? (unlimitedSplits ? "Unlimited" : eventType.displayName)
            : raceName
        let race = Race(
            meetId: meetId,
            name: name,
            eventType: eventType,
            distanceMeters: unlimitedSplits ? 0 : dist,
            trackLengthMeters: track,
            splitsPerLap: (eventType.isRelay || unlimitedSplits) ? 1 : splitsPerLap,
            isUnlimitedSplits: unlimitedSplits,
            athleteIds: orderedIds,
            startedAt: Date(),
            status: .inProgress
        )

        do {
            try store.save(race)
            return race
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
