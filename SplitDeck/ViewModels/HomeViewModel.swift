import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var meets: [Meet] = []
    @Published private(set) var athletes: [Athlete] = []
    @Published private(set) var quickRaces: [Race] = []
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
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
