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

    // MARK: – Bulk Export / Import

    /// Builds a CoachMeetPayload containing this coach's splits for every completed race.
    func buildCoachMeetPayload() -> CoachMeetPayload {
        let completedRaces = races.filter { $0.status == .completed }
        let entries: [RacePayloadEntry] = completedRaces.compactMap { race in
            guard let splits = try? store.fetchSplits(for: race.id) else { return nil }
            let athleteTimingData: [AthleteTimingData] = race.athleteIds.compactMap { athleteId in
                let sorted = splits
                    .filter { $0.athleteId == athleteId }
                    .sorted { $0.lapIndex < $1.lapIndex }
                    .map { $0.elapsedMs }
                guard !sorted.isEmpty else { return nil }
                return AthleteTimingData(athleteId: athleteId, splits: sorted)
            }
            guard !athleteTimingData.isEmpty else { return nil }
            return RacePayloadEntry(
                configId: race.configId ?? UUID(),
                raceId: race.id,
                meetId: meet.id,
                raceName: race.name,
                athleteSplits: athleteTimingData
            )
        }

        return CoachMeetPayload(
            version: 1,
            id: UUID(),
            meetId: meet.id,
            meetName: meet.name,
            coachName: CoachIdentity.name ?? "Coach",
            exportedAt: Date(),
            racePayloads: entries
        )
    }

    /// Verification result for a single race in a bulk import.
    struct RaceMatchResult: Identifiable {
        let id: UUID               // RacePayloadEntry.configId
        let raceName: String
        let athleteCount: Int
        let status: MatchStatus
        let localRace: Race?       // non-nil if matched
        let payload: RacePayloadEntry

        enum MatchStatus {
            case matched            // Race + meet found locally
            case meetNotFound       // Meet ID not in local DB
            case raceNotFound       // Race configId not in local DB
        }
    }

    /// Verifies each race in the payload against the local database.
    func verifyPayload(_ payload: CoachMeetPayload) -> [RaceMatchResult] {
        let meetFound = store.meetExists(id: payload.meetId)

        return payload.racePayloads.map { entry in
            if !meetFound {
                return RaceMatchResult(
                    id: entry.configId,
                    raceName: entry.raceName,
                    athleteCount: entry.athleteSplits.count,
                    status: .meetNotFound,
                    localRace: nil,
                    payload: entry
                )
            }

            if let localRace = store.fetchRace(byConfigId: entry.configId) {
                return RaceMatchResult(
                    id: entry.configId,
                    raceName: entry.raceName,
                    athleteCount: entry.athleteSplits.count,
                    status: .matched,
                    localRace: localRace,
                    payload: entry
                )
            }

            return RaceMatchResult(
                id: entry.configId,
                raceName: entry.raceName,
                athleteCount: entry.athleteSplits.count,
                status: .raceNotFound,
                localRace: nil,
                payload: entry
            )
        }
    }

    /// Bulk merge: for each matched race, replaces the host's splits with merged values.
    func commitBulkMerge(
        results: [RaceMatchResult],
        strategy: SplitMerger.MergeStrategy
    ) {
        let matchedResults = results.filter { $0.status == .matched }

        for result in matchedResults {
            guard let localRace = result.localRace else { continue }
            guard let hostSplits = try? store.fetchSplits(for: localRace.id) else { continue }

            for athleteId in localRace.athleteIds {
                let hostValues = hostSplits
                    .filter { $0.athleteId == athleteId }
                    .sorted { $0.lapIndex < $1.lapIndex }
                    .map { $0.elapsedMs }

                let coachValues = result.payload.athleteSplits
                    .first { $0.athleteId == athleteId }?
                    .splits ?? []

                guard !coachValues.isEmpty else { continue }

                let (merged, _) = SplitMerger.merge(
                    hostSplits: hostValues,
                    coachSplits: [coachValues],
                    strategy: strategy
                )

                let newSplits: [Split] = merged.enumerated().map { index, ms in
                    Split(
                        raceId: localRace.id,
                        athleteId: athleteId,
                        lapIndex: index + 1,
                        elapsedMs: ms
                    )
                }
                try? store.replaceSplits(for: localRace.id, athleteId: athleteId, with: newSplits)
            }
            try? store.markAsMerged(raceId: localRace.id)
        }
        load()
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
