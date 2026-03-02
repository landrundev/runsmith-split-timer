import Foundation
import SwiftUI
import Combine

@MainActor
final class LiveTimingViewModel: ObservableObject {
    @Published private(set) var race: Race
    @Published private(set) var athletes: [Athlete]
    @Published private(set) var splits: [Split] = []
    @Published var showFinishConfirmation = false
    @Published var showResumePrompt = false
    @Published var navigateToResults = false
    @Published var resultsViewModel: ResultsViewModel?
    @Published var shouldDismiss = false
    @Published var errorMessage: String?

    let engine: TimingEngine // exposed so View reads elapsedMs, unassignedMarks

    private let store: SplitDeckStore
    private let cache: RaceStateCache
    private var pendingResumeBlob: RaceStateBlob?
    private var engineCancellable: AnyCancellable?

    init(race: Race, athletes: [Athlete], store: SplitDeckStore, cache: RaceStateCache) {
        self.race = race
        self.athletes = race.athleteIds.compactMap { id in athletes.first { $0.id == id } }
        self.store = store
        self.cache = cache

        self.engine = TimingEngine(
            raceId: race.id,
            splitsPerLap: race.splitsPerLap,
            onSaveSplit: { split in
                try? store.save(split)
            },
            onDeleteSplit: { id in
                try? store.delete(splitId: id)
            },
            onStageCache: { blob in
                cache.stage(blob)
            }
        )

        // Forward engine's tick updates so the view redraws every frame
        engineCancellable = engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: – Lifecycle

    func onAppear() {
        splits = (try? store.fetchSplits(for: race.id)) ?? []

        // Check for a persisted blob from a previous session
        if let blob = cache.load(), blob.raceId == race.id {
            pendingResumeBlob = blob
            showResumePrompt = true
        } else {
            engine.start(at: race.startedAt ?? Date(), existingSplits: splits)
        }

        UIApplication.shared.isIdleTimerDisabled = true
    }

    func onDisappear() {
        engine.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func resumeRace() {
        if let blob = pendingResumeBlob {
            engine.resume(from: blob)
        }
        engine.start(at: race.startedAt ?? Date(), existingSplits: splits)
        pendingResumeBlob = nil
        showResumePrompt = false
    }

    func discardAndStartFresh() {
        cache.clear()
        pendingResumeBlob = nil
        showResumePrompt = false
        engine.start(at: race.startedAt ?? Date(), existingSplits: splits)
    }

    // MARK: – Actions

    func assign(to athlete: Athlete) {
        engine.handleCardTap(athleteId: athlete.id)
        splits = engine.allCurrentSplits
    }

    func mark() {
        if athletes.count == 1, let sole = athletes.first {
            assign(to: sole)
        } else {
            engine.handleMarkTap()
        }
    }

    func undo() {
        engine.undo()
        splits = engine.allCurrentSplits
    }

    func finishRace() {
        var updated = race
        updated.status = .completed
        updated.endedAt = Date()
        do {
            try store.save(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
        cache.clear()
        race = updated
        engine.stop()
        resultsViewModel = ResultsViewModel(
            race: updated,
            athletes: athletes,
            splits: (try? store.fetchSplits(for: updated.id)) ?? splits,
            meet: nil
        )
        navigateToResults = true
    }

    // MARK: – Derived helpers for view

    func splits(for athlete: Athlete) -> [Split] {
        splits.filter { $0.athleteId == athlete.id }
            .sorted { $0.lapIndex < $1.lapIndex }
    }

    func lastSplitSummary(for athlete: Athlete) -> String? {
        guard let last = splits(for: athlete).last else { return nil }
        return "\(last.elapsedMs.formattedSplitTime) (Lap \(last.lapIndex))"
    }

    func lapProgress(for athlete: Athlete) -> String {
        let completed = splits(for: athlete).count
        return "Lap \(min(completed + 1, race.laps)) / \(race.laps)"
    }

    var lapSubtitle: String {
        if race.eventType.isRelay {
            if isRelayComplete {
                return "\(race.eventType.displayName) — Complete"
            }
            let leg = currentRelayLeg + 1
            let name = currentRelayAthlete?.name ?? ""
            return "\(race.eventType.displayName) — Leg \(leg) of 4: \(name)"
        }
        let current = RaceDomain.currentDisplayLap(splits: splits, race: race)
        return "\(race.distanceMeters)m – Lap \(current) of \(race.laps)"
    }

    // MARK: – Relay helpers

    var isRelay: Bool { race.eventType.isRelay }

    /// True when every athlete in the race has recorded all expected splits.
    var allAthletesComplete: Bool {
        guard !isRelay, !athletes.isEmpty else { return false }
        return athletes.allSatisfy { RaceDomain.isComplete(athlete: $0, splits: splits, race: race) }
    }

    /// Number of legs completed so far (0–4).
    var currentRelayLeg: Int {
        guard isRelay else { return 0 }
        return race.athleteIds.filter { id in splits.contains { $0.athleteId == id } }.count
    }

    /// The athlete currently on the track (the next unrecorded leg).
    var currentRelayAthlete: Athlete? {
        guard isRelay else { return nil }
        let leg = currentRelayLeg
        guard leg < race.athleteIds.count else { return nil }
        return athletes.first { $0.id == race.athleteIds[leg] }
    }

    /// True when all 4 legs have been recorded.
    var isRelayComplete: Bool {
        guard isRelay else { return false }
        return currentRelayLeg >= race.athleteIds.count
    }

    /// Record the current relay leg and advance. Auto-finishes when the last leg is done.
    func recordRelayLeg() {
        guard let athlete = currentRelayAthlete else { return }
        assign(to: athlete)
    }

    /// Reorder upcoming relay legs. Only legs that haven't run yet can be moved.
    func moveRelayLeg(from source: IndexSet, to destination: Int) {
        let firstMutableIndex = currentRelayLeg
        // Only allow moves within the mutable (not-yet-run) portion
        guard source.allSatisfy({ $0 >= firstMutableIndex }),
              destination >= firstMutableIndex else { return }
        var updatedIds = race.athleteIds
        updatedIds.move(fromOffsets: source, toOffset: destination)
        race.athleteIds = updatedIds
        athletes = updatedIds.compactMap { id in athletes.first { $0.id == id } }
        try? store.save(race)
    }

    // MARK: – Background flush blob

    var currentBlob: RaceStateBlob {
        RaceStateBlob(
            raceId: race.id,
            unassignedMarks: engine.unassignedMarks,
            undoStack: engine.undoStack,
            capturedAt: Date()
        )
    }
}
