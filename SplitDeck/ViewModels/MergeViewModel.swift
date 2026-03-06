import Foundation
import Combine

/// Drives the host coach's Merge Coach Data screen.
///
/// Responsibilities:
/// - Hold imported `CoachSplitPayload` objects (one per assistant coach).
/// - Compute a live preview of merged splits using `SplitMerger`.
/// - Commit the final merged splits to Core Data via `SplitDeckStore.replaceSplits`.
@MainActor
final class MergeViewModel: ObservableObject {

    // MARK: – Published State

    /// Payloads imported from assistant coaches (via QR scan or file).
    @Published var importedPayloads: [CoachSplitPayload] = []

    /// The current merge preview, one entry per athlete.
    /// Empty until at least one payload is imported.
    @Published var mergePreview: [SplitMerger.MergedResult] = []

    /// Which merge algorithm to use. Changing this recomputes the preview.
    @Published var mergeStrategy: SplitMerger.MergeStrategy = .median

    /// Controls whether the QR scanner sheet is presented.
    @Published var showScanner = false

    /// Set to `true` after `commitMerge()` succeeds.
    @Published var isMerged = false

    /// Set to `true` when an imported payload's configId doesn't match this race.
    @Published var showWrongRaceError = false

    // MARK: – Inputs (immutable after init)

    /// The race whose splits are being merged.
    let race: Race

    /// Athletes in this race, in display order.
    let athletes: [Athlete]

    /// The host coach's own splits — the authoritative source before any merge.
    let hostSplits: [Split]

    // MARK: – Dependencies

    private let store: SplitDeckStore

    // MARK: – Init

    init(race: Race, athletes: [Athlete], hostSplits: [Split], store: SplitDeckStore) {
        self.race = race
        self.athletes = athletes
        self.hostSplits = hostSplits
        self.store = store
    }

    // MARK: – Import

    /// Imports a `CoachSplitPayload` from an assistant coach.
    ///
    /// Validates configId match (if the race has one) to prevent merging splits
    /// from a different race. Deduplicates by `coachName` + `exportedAt` so
    /// scanning the same QR twice does not add a duplicate entry.
    func importPayload(_ payload: CoachSplitPayload) {
        if let raceConfigId = race.configId, payload.configId != raceConfigId {
            showWrongRaceError = true
            return
        }

        let isDuplicate = importedPayloads.contains {
            $0.coachName == payload.coachName && $0.exportedAt == payload.exportedAt
        }
        guard !isDuplicate else { return }
        importedPayloads.append(payload)
        computePreview()
    }

    /// Removes the payload at the given index and recomputes the preview.
    func removePayload(at index: Int) {
        guard importedPayloads.indices.contains(index) else { return }
        importedPayloads.remove(at: index)
        computePreview()
    }

    // MARK: – Preview

    /// Recomputes `mergePreview` from the current payloads and strategy.
    ///
    /// Called automatically after every import/remove and whenever `mergeStrategy` changes.
    func computePreview() {
        mergePreview = athletes.map { athlete in
            // Host's splits for this athlete, sorted ascending by lapIndex.
            let hostValues: [Int] = hostSplits
                .filter { $0.athleteId == athlete.id }
                .sorted { $0.lapIndex < $1.lapIndex }
                .map { $0.elapsedMs }

            // Each imported coach's splits for this athlete (empty array if none recorded).
            let coachValues: [[Int]] = importedPayloads.map { payload in
                payload.athleteSplits
                    .first { $0.athleteId == athlete.id }?
                    .splits ?? []
            }

            let (merged, flags) = SplitMerger.merge(
                hostSplits: hostValues,
                coachSplits: coachValues,
                strategy: mergeStrategy
            )

            return SplitMerger.MergedResult(
                athleteId: athlete.id,
                athleteName: athlete.name,
                originalSplits: hostValues,
                coachSplits: coachValues,
                mergedSplits: merged,
                flags: flags
            )
        }
    }

    // MARK: – Commit

    /// Writes merged splits to Core Data, replacing the host's original splits.
    ///
    /// For each athlete in `mergePreview`, creates new `Split` objects from
    /// `mergedSplits` and calls `store.replaceSplits(for:athleteId:with:)`.
    /// Sets `isMerged = true` on success (even if some athletes had no splits to replace).
    func commitMerge() {
        for result in mergePreview {
            let newSplits: [Split] = result.mergedSplits.enumerated().map { index, ms in
                Split(
                    raceId: race.id,
                    athleteId: result.athleteId,
                    lapIndex: index + 1,
                    elapsedMs: ms
                )
            }
            try? store.replaceSplits(
                for: race.id,
                athleteId: result.athleteId,
                with: newSplits
            )
        }
        try? store.markAsMerged(raceId: race.id)
        isMerged = true
    }
}
