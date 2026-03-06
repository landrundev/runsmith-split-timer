import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var meets: [Meet] = []
    @Published private(set) var athletes: [Athlete] = []
    @Published private(set) var quickRaces: [Race] = []
    @Published private(set) var meetRaces: [UUID: [Race]] = [:]
    @Published var errorMessage: String?

    private let store: SplitDeckStore

    init(store: SplitDeckStore) {
        self.store = store
    }

    func load() {
        do {
            meets = try store.fetchMeets()
            athletes = try store.fetchAthletes()
            quickRaces = try store.fetchRaces(for: nil)
            var lookup: [UUID: [Race]] = [:]
            for meet in meets {
                lookup[meet.id] = try store.fetchRaces(for: meet.id)
            }
            meetRaces = lookup
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Derives a meet's overall status from its races.
    func meetStatus(for meet: Meet) -> RaceStatus {
        let races = meetRaces[meet.id] ?? []
        guard !races.isEmpty else { return .notStarted }
        if races.allSatisfy({ $0.status == .completed }) { return .completed }
        if races.contains(where: { $0.status == .inProgress || $0.status == .completed }) { return .inProgress }
        return .notStarted
    }

    func save(meet: Meet) {
        do {
            try store.save(meet)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(meet: Meet) {
        do {
            try store.delete(meetId: meet.id)
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

    func save(athlete: Athlete) {
        do {
            try store.save(athlete)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(athlete: Athlete) {
        do {
            try store.delete(athleteId: athlete.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archive(meet: Meet) {
        do {
            try store.archive(meetId: meet.id)
            load()
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
