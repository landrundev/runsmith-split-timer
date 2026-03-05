import Foundation

struct AthleteRaceResult: Identifiable {
    let id: UUID           // race ID
    let raceName: String
    let eventType: EventType
    let date: Date?
    let finalTimeMs: Int?  // nil if DNF or unlimited
    let place: Int?        // nil if incomplete or unlimited
    let splitCount: Int
    let isUnlimited: Bool
    let splitLabels: [String]    // e.g. ["400m", "800m"] or ["Split 1", "Split 2"]
    let cumulativeTimesMs: [Int] // elapsed times per split, sorted by lap index
    let lapTimesMs: [Int]        // per-split deltas
}

@MainActor
final class AthleteProfileViewModel: ObservableObject {
    @Published private(set) var raceHistory: [AthleteRaceResult] = []
    @Published private(set) var personalBests: [(eventType: EventType, timeMs: Int)] = []
    @Published var errorMessage: String?

    @Published var athlete: Athlete
    private let store: SplitDeckStore

    init(athlete: Athlete, store: SplitDeckStore) {
        self.athlete = athlete
        self.store = store
    }

    func save(_ updated: Athlete) {
        do {
            try store.save(updated)
            athlete = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAthlete() throws {
        try store.delete(athleteId: athlete.id)
    }

    func deleteRace(id: UUID) {
        do {
            try store.delete(raceId: id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() {
        do {
            let races = try store.fetchRaces(forAthlete: athlete.id)
                .filter { $0.status == .completed }
            let allAthletes = try store.fetchAthletes()

            var results: [AthleteRaceResult] = []
            var bests: [EventType: Int] = [:]

            for race in races {
                let allSplits = try store.fetchSplits(for: race.id)
                let athleteSplits = allSplits.filter { $0.athleteId == athlete.id }
                let raceAthletes = race.athleteIds.compactMap { id in
                    allAthletes.first { $0.id == id }
                }

                let finalTime = RaceDomain.finalTime(
                    athlete: athlete, splits: allSplits, race: race
                )
                let ranking = RaceDomain.ranked(
                    athletes: raceAthletes, splits: allSplits, race: race
                )
                let place = ranking.first { $0.athlete.id == athlete.id }?.place

                let sortedSplits = athleteSplits.sorted { $0.elapsedMs < $1.elapsedMs }
                let cumulativeTimes = sortedSplits.map(\.elapsedMs)
                let lapTimes = sortedSplits.enumerated().map { i, split in
                    i == 0 ? split.elapsedMs : split.elapsedMs - sortedSplits[i - 1].elapsedMs
                }
                let labels = RaceDomain.cumulativeColumnLabels(for: race, splits: allSplits)

                results.append(AthleteRaceResult(
                    id: race.id,
                    raceName: race.name,
                    eventType: race.eventType,
                    date: race.startedAt,
                    finalTimeMs: finalTime,
                    place: place,
                    splitCount: athleteSplits.count,
                    isUnlimited: race.isUnlimitedSplits,
                    splitLabels: labels,
                    cumulativeTimesMs: cumulativeTimes,
                    lapTimesMs: lapTimes
                ))

                // Track personal bests (bounded races with a finish time only)
                if let time = finalTime, !race.isUnlimitedSplits {
                    bests[race.eventType] = min(bests[race.eventType] ?? Int.max, time)
                }
            }

            self.raceHistory = results
            self.personalBests = bests
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { (eventType: $0.key, timeMs: $0.value) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
