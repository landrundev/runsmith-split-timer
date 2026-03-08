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

    // MARK: \u{2013} Load

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

    // MARK: \u{2013} Quick Race Subsets

    var pendingQuickRaces: [Race] {
        quickRaces.filter { $0.status == .notStarted }
    }

    /// All started/completed quick races, newest first.
    var startedQuickRaces: [Race] {
        quickRaces
            .filter { $0.status != .notStarted }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    /// Whether there are more than the Home preview limit.
    var hasMoreHistory: Bool {
        startedQuickRaces.count > 10
    }

    // MARK: \u{2013} Hero Card Helpers

    /// The nearest future (or today) non-archived meet.
    var nextMeet: Meet? {
        let today = Calendar.current.startOfDay(for: Date())
        return meets
            .filter { !$0.isArchived && Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    /// Overall meet status derived from its races.
    func meetStatus(for meet: Meet) -> RaceStatus {
        let races = meetRaces[meet.id] ?? []
        guard !races.isEmpty else { return .notStarted }
        if races.allSatisfy({ $0.status == .completed }) { return .completed }
        if races.contains(where: { $0.status == .inProgress || $0.status == .completed }) { return .inProgress }
        return .notStarted
    }

    /// Number of completed races in this meet.
    func completedRaceCount(for meet: Meet) -> Int {
        (meetRaces[meet.id] ?? []).filter { $0.status == .completed }.count
    }

    /// Total race count for a meet.
    func totalRaceCount(for meet: Meet) -> Int {
        meetRaces[meet.id]?.count ?? 0
    }

    /// The next race in the meet that hasn't started yet.
    func nextUnstartedRace(for meet: Meet) -> Race? {
        (meetRaces[meet.id] ?? []).first(where: { $0.status == .notStarted })
    }

    /// A race currently in progress in this meet.
    func inProgressRace(for meet: Meet) -> Race? {
        (meetRaces[meet.id] ?? []).first(where: { $0.status == .inProgress })
    }

    // MARK: \u{2013} Actions

    func save(meet: Meet) {
        do { try store.save(meet); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(meet: Meet) {
        do { try store.delete(meetId: meet.id); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(race: Race) {
        do { try store.delete(raceId: race.id); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func save(athlete: Athlete) {
        do { try store.save(athlete); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(athlete: Athlete) {
        do { try store.delete(athleteId: athlete.id); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func archive(meet: Meet) {
        do { try store.archive(meetId: meet.id); load() }
        catch { errorMessage = error.localizedDescription }
    }

    func archive(race: Race) {
        do { try store.archive(raceId: race.id); load() }
        catch { errorMessage = error.localizedDescription }
    }
}
