import Foundation

@MainActor
final class MeetDetailViewModel: ObservableObject {
    @Published private(set) var races: [Race] = []
    @Published private(set) var athletes: [Athlete] = []
    @Published var errorMessage: String?

    let meet: Meet
    private let store: SplitDeckStore

    init(meet: Meet, store: SplitDeckStore) {
        self.meet = meet
        self.store = store
    }

    func load() {
        do {
            races = try store.fetchRaces(for: meet.id)
            athletes = try store.fetchAthletes()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func archive(race: Race) {
        do {
            try store.archive(raceId: race.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
