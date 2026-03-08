import Foundation

@MainActor
final class MeetDetailViewModel: ObservableObject {
    @Published private(set) var races: [Race] = []
    @Published private(set) var athletes: [Athlete] = []
    @Published var errorMessage: String?

    /// Best (fastest) finish time per race, keyed by race ID.
    /// Only populated for completed individual races.
    @Published private(set) var bestTimes: [UUID: Int] = [:]

    @Published var meet: Meet
    private let store: SplitDeckStore

    init(meet: Meet, store: SplitDeckStore) {
        self.meet = meet
        self.store = store
    }

    func updateMeet(name: String, date: Date, location: String?) {
        meet = Meet(id: meet.id, name: name, date: date, location: location, isArchived: meet.isArchived)
        do {
            try store.save(meet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() {
        do {
            races = try store.fetchRaces(for: meet.id)
            athletes = try store.fetchAthletes()
            loadBestTimes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: \u{2013} Best Times

    /// For each completed, non-relay race, find the fastest athlete's finish time.
    private func loadBestTimes() {
        var lookup: [UUID: Int] = [:]
        for race in races where race.status == .completed && !race.eventType.isRelay {
            do {
                let splits = try store.fetchSplits(for: race.id)
                let raceAthletes = race.athleteIds.compactMap { id in
                    athletes.first { $0.id == id }
                }
                // Collect all valid final times, pick the minimum
                let times = raceAthletes.compactMap { athlete in
                    RaceDomain.finalTime(athlete: athlete, splits: splits, race: race)
                }
                if let best = times.min() {
                    lookup[race.id] = best
                }
            } catch {
                // Skip this race on error
            }
        }
        bestTimes = lookup
    }

    /// Formatted best time string for display, or nil.
    func bestTimeDisplay(for race: Race) -> String? {
        guard let ms = bestTimes[race.id] else { return nil }
        return ms.formattedSplitTime
    }

    func save(race: Race) {
        do {
            try store.save(race)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(race: Race) {
        do {
            try store.delete(raceId: race.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Multi-Coach Sharing

    /// Assembles the meet and all its races into a SharedMeetConfig
    /// that assistant coaches can import on their devices.
    func buildSharedMeetConfig() -> SharedMeetConfig {
        let raceConfigs = races.map { race -> SharedRaceConfig in
            let raceAthletes = race.athleteIds.compactMap { id in
                athletes.first { $0.id == id }
            }

            return SharedRaceConfig(
                version: 1,
                configId: UUID(),
                hostCoachName: CoachIdentity.name ?? "Host",
                meetName: meet.name,
                raceName: race.name,
                eventType: race.eventType,
                distanceMeters: race.distanceMeters,
                trackLengthMeters: race.trackLengthMeters,
                splitsPerLap: race.splitsPerLap,
                isUnlimitedSplits: race.isUnlimitedSplits,
                athletes: raceAthletes.map { athlete in
                    SharedAthlete(
                        id: athlete.id,
                        name: athlete.name,
                        gender: athlete.gender,
                        colorHex: athlete.colorHex
                    )
                }
            )
        }

        return SharedMeetConfig(
            version: 1,
            configId: UUID(),
            hostCoachName: CoachIdentity.name ?? "Host",
            meetName: meet.name,
            meetDate: meet.date,
            meetLocation: meet.location,
            races: raceConfigs
        )
    }

    func moveRace(from source: IndexSet, to destination: Int) {
        var reordered = races
        reordered.move(fromOffsets: source, toOffset: destination)
        races = reordered
        do {
            try store.updateRaceSortOrders(reordered.map(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archive(race: Race) {
        do {
            try store.archive(raceId: race.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
