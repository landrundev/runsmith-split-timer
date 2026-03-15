import Foundation
import SwiftUI
import Combine

@MainActor
final class LiveTimingViewModel: ObservableObject {
    @Published private(set) var race: Race
    @Published private(set) var athletes: [Athlete]
    @Published private(set) var splits: [Split] = []
    @Published var showFinishConfirmation = false
    @Published var showDNFConfirmation = false
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

        // Don't restart engine if race is already finished
        guard race.status != .completed else { return }

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

    func discardRace() {
        engine.stop()
        cache.clear()
        try? store.delete(raceId: race.id)
        shouldDismiss = true
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
        if race.isUnlimitedSplits {
            return "\(last.elapsedMs.formattedSplitTime) (Split \(last.lapIndex))"
        }
        return "\(last.elapsedMs.formattedSplitTime) (Lap \(last.lapIndex))"
    }

    func lastSplitTime(for athlete: Athlete) -> String? {
        splits(for: athlete).last.map { $0.elapsedMs.formattedSplitTime }
    }

    /// All recorded splits for display on full-size cards: (label, cumulative, lapDelta)
    func splitTimesForDisplay(for athlete: Athlete) -> [(label: String, cumulative: String, lap: String)] {
        let sorted = splits(for: athlete)
        guard !sorted.isEmpty else { return [] }

        let splitDistance: Int? = {
            guard !race.isUnlimitedSplits else { return nil }
            return race.splitDistanceMeters
        }()

        return sorted.enumerated().map { i, split in
            let label: String
            if let dist = splitDistance {
                label = "\(dist * (i + 1))m"
            } else {
                label = "Split \(i + 1)"
            }
            let cumulative = split.elapsedMs.formattedSplitTime
            let prev = i > 0 ? sorted[i - 1].elapsedMs : 0
            let lap = (split.elapsedMs - prev).formattedSplitTime
            return (label: label, cumulative: cumulative, lap: lap)
        }
    }

    /// Last lap delta time for compact cards
    func lastLapDelta(for athlete: Athlete) -> String? {
        let sorted = splits(for: athlete)
        guard let last = sorted.last else { return nil }
        let prev = sorted.count >= 2 ? sorted[sorted.count - 2].elapsedMs : 0
        return (last.elapsedMs - prev).formattedSplitTime
    }

    /// Last lap delta in raw milliseconds (used by pace calculation).
    func lastLapDeltaMs(for athlete: Athlete) -> Int? {
        let sorted = splits(for: athlete)
        guard let last = sorted.last else { return nil }
        let prev = sorted.count >= 2 ? sorted[sorted.count - 2].elapsedMs : 0
        return last.elapsedMs - prev
    }

    /// Formatted pace string for the athlete's most recent lap, e.g. "5:12/mi".
    func paceDisplay(for athlete: Athlete) -> String? {
        guard let deltaMs = lastLapDeltaMs(for: athlete) else { return nil }
        let lapMeters = race.splitDistanceMeters
        let raw = UserDefaults.standard.string(forKey: "paceUnit") ?? PaceUnit.perMile.rawValue
        let unit = PaceUnit(rawValue: raw) ?? .perMile
        return PaceCalculator.format(lapMs: deltaMs, lapMeters: lapMeters, unit: unit)
    }

    /// Last cumulative time for compact cards
    func lastCumulativeTime(for athlete: Athlete) -> String? {
        splits(for: athlete).last.map { $0.elapsedMs.formattedSplitTime }
    }

    /// Formatted finish time for a completed athlete, or nil if not finished.
    func finishTimeForDisplay(for athlete: Athlete) -> String? {
        guard let ms = RaceDomain.finalTime(athlete: athlete, splits: splits, race: race) else {
            return nil
        }
        return ms.formattedSplitTime
    }

    /// Current lap elapsed time (ms since last recorded split) for single-athlete races.
    /// Returns nil on the first lap (total elapsed IS lap elapsed), when complete, or for multi-athlete/relay.
    var singleAthleteLapElapsedMs: Int? {
        guard !isRelay, athletes.count == 1, let athlete = athletes.first else { return nil }
        guard !RaceDomain.isComplete(athlete: athlete, splits: splits, race: race) else { return nil }
        let athleteSplits = splits(for: athlete)
        guard let lastMs = athleteSplits.last?.elapsedMs else { return nil }
        return max(0, engine.elapsedMs - lastMs)
    }

    /// Label for the current lap timer, e.g. "Lap 2" or "Split 3".
    var singleAthleteLapLabel: String? {
        guard !isRelay, athletes.count == 1, let athlete = athletes.first else { return nil }
        let completed = splits(for: athlete).count
        guard completed > 0 else { return nil }
        if race.isUnlimitedSplits {
            return "Split \(completed + 1)"
        }
        return "Lap \(min(completed + 1, race.laps))"
    }

    func lapProgress(for athlete: Athlete) -> String {
        let completed = splits(for: athlete).count
        if race.isUnlimitedSplits {
            return "Split \(completed)"
        }
        if race.splitsPerLap > 1 {
            let total = race.expectedSplitsPerAthlete
            return "Split \(min(completed + 1, total)) / \(total)"
        }
        return "Lap \(min(completed + 1, race.laps)) / \(race.laps)"
    }

    var lapSubtitle: String {
        if race.eventType.isRelay {
            if isRelayComplete {
                return "\(race.eventType.displayName) — Complete"
            }
            let leg = currentRelayLeg + 1
            let name = currentRelayAthlete?.name ?? ""
            if race.splitsPerLap > 1, let distLabel = currentSplitDistanceLabel {
                return "\(race.eventType.displayName) — Leg \(leg): \(name) (\(distLabel))"
            }
            return "\(race.eventType.displayName) — Leg \(leg) of 4: \(name)"
        }
        if race.isUnlimitedSplits {
            let totalSplits = splits.count
            return "Unlimited — \(totalSplits) split\(totalSplits == 1 ? "" : "s") recorded"
        }
        if race.splitsPerLap > 1 {
            let totalSplits = race.expectedSplitsPerAthlete
            let maxCompleted = Dictionary(grouping: splits, by: \.athleteId)
                .values.map(\.count).max() ?? 0
            let currentSplit = min(maxCompleted + 1, totalSplits)
            return "\(race.distanceMeters)m – Split \(currentSplit) of \(totalSplits)"
        }
        let current = RaceDomain.currentDisplayLap(splits: splits, race: race)
        return "\(race.distanceMeters)m – Lap \(current) of \(race.laps)"
    }

    // MARK: – Relay helpers

    var isRelay: Bool { race.eventType.isRelay }

    /// True when every athlete in the race has recorded all expected splits.
    var allAthletesComplete: Bool {
        guard !isRelay, !athletes.isEmpty, !race.isUnlimitedSplits else { return false }
        return athletes.allSatisfy { RaceDomain.isComplete(athlete: $0, splits: splits, race: race) }
    }

    /// True when at least one athlete hasn't finished (individual or relay).
    var hasIncompleteAthletes: Bool {
        if isRelay { return !isRelayComplete }
        guard !athletes.isEmpty, !race.isUnlimitedSplits else { return false }
        return !allAthletesComplete
    }

    /// Number of legs completed so far (0–4).
    /// An athlete's leg is complete when they have recorded ALL expected splits
    /// (splitsPerLap splits). For splitsPerLap=1, this is 1 tap. For splitsPerLap=2,
    /// this is 2 taps (intermediate + leg completion).
    var currentRelayLeg: Int {
        guard isRelay else { return 0 }
        let expectedSplits = race.splitsPerLap
        return race.athleteIds.filter { id in
            splits.filter { $0.athleteId == id }.count >= expectedSplits
        }.count
    }

    /// The athlete currently on the track (the next unrecorded leg).
    var currentRelayAthlete: Athlete? {
        guard isRelay else { return nil }
        let leg = currentRelayLeg
        guard leg < race.athleteIds.count else { return nil }
        return athletes.first { $0.id == race.athleteIds[leg] }
    }

    /// For relays with intermediate splits: which split within the current leg
    /// the coach needs to record next (1-based). Returns 1 for "record 200m",
    /// 2 for "record 400m" in a 4×400m relay with intermediates.
    var currentLegSplitNumber: Int {
        guard isRelay, let athlete = currentRelayAthlete else { return 1 }
        let recorded = splits.filter { $0.athleteId == athlete.id }.count
        return recorded + 1
    }

    /// True if the current relay athlete has more splits to record before
    /// their leg is complete.
    var isCurrentLegPartial: Bool {
        guard isRelay else { return false }
        return currentLegSplitNumber <= race.splitsPerLap && currentLegSplitNumber > 1
    }

    /// Label for the current split distance the coach needs to record.
    /// e.g. "200m" for the first tap, "400m" for the second tap in a 4×400m relay.
    var currentSplitDistanceLabel: String? {
        guard isRelay, race.splitsPerLap > 1,
              let intermediateDist = race.intermediateDistanceMeters else { return nil }
        return "\(intermediateDist * currentLegSplitNumber)m"
    }

    /// Returns the leg delta time (time for that specific leg) for a completed leg.
    /// Uses the athlete's LAST split (leg completion) minus the previous athlete's last split.
    func relayLegDelta(legIndex: Int) -> Int? {
        guard isRelay, legIndex < race.athleteIds.count else { return nil }
        let athleteId = race.athleteIds[legIndex]
        let athleteSplits = splits.filter { $0.athleteId == athleteId }
            .sorted { $0.elapsedMs < $1.elapsedMs }
        guard let lastSplit = athleteSplits.last else { return nil }

        let prevCumulative: Int
        if legIndex > 0 {
            let prevAthleteId = race.athleteIds[legIndex - 1]
            prevCumulative = splits.filter { $0.athleteId == prevAthleteId }
                .sorted { $0.elapsedMs < $1.elapsedMs }
                .last?.elapsedMs ?? 0
        } else {
            prevCumulative = 0
        }
        return lastSplit.elapsedMs - prevCumulative
    }

    /// Returns all split times for a relay leg, including intermediates.
    /// - `legCumulMs`: time from leg start to this split
    /// - `lapMs`: split-to-split delta (time for just this segment)
    /// - `raceCumulMs`: total elapsed from race start
    func relayLegSplitDetails(legIndex: Int) -> [(label: String, legCumulMs: Int, lapMs: Int, raceCumulMs: Int)] {
        guard isRelay, legIndex < race.athleteIds.count else { return [] }
        let athleteId = race.athleteIds[legIndex]
        let athleteSplits = splits.filter { $0.athleteId == athleteId }
            .sorted { $0.elapsedMs < $1.elapsedMs }
        guard !athleteSplits.isEmpty else { return [] }

        // Previous leg's last cumulative (or 0 for leg 1)
        let prevCumulative: Int
        if legIndex > 0 {
            let prevAthleteId = race.athleteIds[legIndex - 1]
            prevCumulative = splits.filter { $0.athleteId == prevAthleteId }
                .sorted { $0.elapsedMs < $1.elapsedMs }
                .last?.elapsedMs ?? 0
        } else {
            prevCumulative = 0
        }

        let intermediateDist = race.trackLengthMeters / max(race.splitsPerLap, 1)
        var results: [(label: String, legCumulMs: Int, lapMs: Int, raceCumulMs: Int)] = []
        for (i, split) in athleteSplits.enumerated() {
            let label = "\(intermediateDist * (i + 1))m"
            let legCumul = split.elapsedMs - prevCumulative
            let prevElapsed = i > 0 ? athleteSplits[i - 1].elapsedMs : prevCumulative
            let lap = split.elapsedMs - prevElapsed
            results.append((label: label, legCumulMs: legCumul, lapMs: lap, raceCumulMs: split.elapsedMs))
        }
        return results
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
