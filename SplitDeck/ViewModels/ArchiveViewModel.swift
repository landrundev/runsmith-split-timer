import Foundation

@MainActor
final class ArchiveViewModel: ObservableObject {
    @Published private(set) var archivedMeets: [Meet] = []
    @Published private(set) var archivedRaces: [Race] = []
    @Published private(set) var archivedAthletes: [Athlete] = []
    @Published private(set) var allAthletes: [Athlete] = []
    @Published var errorMessage: String?

    let store: SplitDeckStore

    init(store: SplitDeckStore) {
        self.store = store
    }

    /// Archived quick races (meetId == nil)
    var archivedQuickRaces: [Race] {
        archivedRaces.filter { $0.meetId == nil }
    }

    func load() {
        do {
            archivedMeets = try store.fetchArchivedMeets()
            archivedRaces = try store.fetchArchivedRaces()
            archivedAthletes = try store.fetchArchivedAthletes()
            allAthletes = try store.fetchAthletes() + archivedAthletes
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Unarchive

    func unarchive(meet: Meet) {
        do {
            try store.unarchive(meetId: meet.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unarchive(race: Race) {
        do {
            try store.unarchive(raceId: race.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unarchive(athlete: Athlete) {
        do {
            try store.unarchive(athleteId: athlete.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Permanent Delete

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

    func delete(athlete: Athlete) {
        do {
            try store.delete(athleteId: athlete.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
