import Foundation

enum RankingMode: String, CaseIterable {
    case pr = "PR"
    case average = "Average"
    case roster = "Roster"
}

@MainActor
final class RelayBuilderViewModel: ObservableObject {

    // MARK: – Inputs

    @Published var selectedRelayType: EventType = .relay4x100 {
        didSet {
            // Reset intermediate splits if new type doesn't support it
            if selectedRelayType != .relay4x400 && selectedRelayType != .relay4x800 {
                splitsPerLap = 1
            }
            refreshCandidates()
        }
    }
    @Published var splitsPerLap: Int = 1
    @Published var selectedGender: Gender = .male {
        didSet { refreshCandidates() }
    }
    @Published var rankingMode: RankingMode = .pr {
        didSet { refreshCandidates() }
    }

    // MARK: – Outputs

    @Published private(set) var candidates: [AthleteRelayCandidate] = []
    @Published var chosenAthleteIds: [UUID] = []
    @Published private(set) var suggestedOrder: [AthleteRelayCandidate]?
    @Published private(set) var savedTeams: [SavedRelayTeam] = []
    @Published var errorMessage: String?

    // MARK: – Cached data

    private var allAthletes: [Athlete] = []
    private var completedRaces: [Race] = []
    private var splitsByRaceId: [UUID: [Split]] = [:]

    let store: SplitDeckStore

    init(store: SplitDeckStore) {
        self.store = store
    }

    // MARK: – Load

    func load() {
        do {
            allAthletes = try store.fetchAthletes()
            completedRaces = try store.fetchAllCompletedRaces()
            savedTeams = try store.fetchSavedRelayTeams()

            splitsByRaceId = [:]
            for race in completedRaces {
                splitsByRaceId[race.id] = try store.fetchSplits(for: race.id)
            }

            refreshCandidates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshCandidates() {
        let previousChosenIds = chosenAthleteIds
        suggestedOrder = nil
        switch rankingMode {
        case .pr:
            candidates = RelayRecommender.rankCandidates(
                relayEventType: selectedRelayType,
                gender: selectedGender,
                athletes: allAthletes,
                races: completedRaces,
                splitsByRaceId: splitsByRaceId
            )
        case .average:
            candidates = RelayRecommender.rankCandidatesByAverage(
                relayEventType: selectedRelayType,
                gender: selectedGender,
                athletes: allAthletes,
                races: completedRaces,
                splitsByRaceId: splitsByRaceId
            )
        case .roster:
            candidates = allAthletes
                .filter { $0.gender == selectedGender }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { AthleteRelayCandidate(id: $0.id, athlete: $0, bestTimeMs: 0, source: .roster) }
        }

        // Preserve selections that still exist in the new candidate list
        let candidateIdSet = Set(candidates.map(\.id))
        chosenAthleteIds = previousChosenIds.filter { candidateIdSet.contains($0) }
    }

    // MARK: – Selection

    var chosenCandidates: [AthleteRelayCandidate] {
        chosenAthleteIds.compactMap { id in candidates.first { $0.id == id } }
    }

    var isTeamComplete: Bool { chosenAthleteIds.count == 4 }

    func toggleAthlete(_ id: UUID) {
        if let idx = chosenAthleteIds.firstIndex(of: id) {
            chosenAthleteIds.remove(at: idx)
            suggestedOrder = nil
        } else {
            guard chosenAthleteIds.count < 4 else { return }
            chosenAthleteIds.append(id)
            if chosenAthleteIds.count == 4 && rankingMode != .roster {
                suggestedOrder = RelayRecommender.suggestLegOrder(chosenCandidates)
            }
        }
    }

    func moveLeg(from source: IndexSet, to destination: Int) {
        chosenAthleteIds.move(fromOffsets: source, toOffset: destination)
    }

    func applySuggestedOrder() {
        guard let suggested = suggestedOrder else { return }
        chosenAthleteIds = suggested.map(\.id)
    }

    // MARK: – Save / Load Teams

    func saveTeam(name: String) {
        guard isTeamComplete else { return }
        let team = SavedRelayTeam(
            name: name,
            eventType: selectedRelayType,
            gender: selectedGender,
            athleteIds: chosenAthleteIds
        )
        do {
            try store.save(team)
            savedTeams = try store.fetchSavedRelayTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTeam(_ team: SavedRelayTeam) {
        do {
            try store.delete(relayTeamId: team.id)
            savedTeams = try store.fetchSavedRelayTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTeam(_ team: SavedRelayTeam) {
        selectedRelayType = team.eventType
        selectedGender = team.gender
        // refreshCandidates() fires from didSet, resets chosenAthleteIds
        // Re-select the team's athletes (in order) after refresh
        chosenAthleteIds = team.athleteIds.filter { id in
            candidates.contains { $0.id == id }
        }
        if chosenAthleteIds.count == 4 {
            suggestedOrder = RelayRecommender.suggestLegOrder(chosenCandidates)
        }
    }

    // MARK: – Start Race

    func startRace(meetId: UUID?) -> Race? {
        guard isTeamComplete else { return nil }
        let legDist = selectedRelayType.legDistanceMeters!
        let name = "\(selectedGender.displayName) \(selectedRelayType.displayName)"
        let race = Race(
            meetId: meetId,
            name: name,
            eventType: selectedRelayType,
            distanceMeters: legDist,
            trackLengthMeters: legDist,
            splitsPerLap: splitsPerLap,
            athleteIds: chosenAthleteIds,
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

    // MARK: – Helpers

    func athlete(for id: UUID) -> Athlete? {
        allAthletes.first { $0.id == id }
    }

    // MARK: – Computed

    var filteredSavedTeams: [SavedRelayTeam] {
        savedTeams.filter { $0.gender == selectedGender }
    }

    var projectedTotalMs: Int? {
        guard isTeamComplete, rankingMode != .roster else { return nil }
        let times = chosenCandidates.map(\.bestTimeMs)
        guard times.count == 4 else { return nil }
        return times.reduce(0, +)
    }

    var legDistanceDisplay: String {
        guard let d = selectedRelayType.legDistanceMeters else { return "" }
        return "\(d)m"
    }

    var supportsIntermediateSplits: Bool {
        selectedRelayType == .relay4x400 || selectedRelayType == .relay4x800
    }

    var intermediateSplitLabel: String? {
        guard supportsIntermediateSplits, let leg = selectedRelayType.legDistanceMeters else { return nil }
        return "\(leg / 2)m"
    }
}
