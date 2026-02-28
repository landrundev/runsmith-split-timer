import Foundation

@MainActor
final class MeetDetailViewModel: ObservableObject {
    @Published private(set) var races: [Race] = []
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
}
