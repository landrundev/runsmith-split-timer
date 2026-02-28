import Foundation
import QuartzCore
import UIKit

// MARK: – UndoAction

enum UndoAction: Codable, Equatable {
    case markCreated(markId: UUID)
    case splitAssigned(splitId: UUID, consumedMarkId: UUID?)
}

// MARK: – RaceStateBlob

struct RaceStateBlob: Codable {
    let raceId: UUID
    let unassignedMarks: [UnassignedMark]
    let undoStack: [UndoAction]
    let capturedAt: Date
}

// MARK: – TimingEngine

@MainActor
final class TimingEngine: ObservableObject {

    @Published private(set) var elapsedMs: Int = 0
    @Published private(set) var unassignedMarks: [UnassignedMark] = []
    @Published private(set) var undoStack: [UndoAction] = []

    private var currentSplits: [Split] = [] // in-memory mirror of persisted splits
    private var startedAt: Date?
    private var displayLink: CADisplayLink?

    let raceId: UUID
    let splitsPerLap: Int

    // Injected — no direct dependency on Core Data or RaceStateCache
    private let onSaveSplit: (Split) -> Void
    private let onDeleteSplit: (UUID) -> Void
    private let onStageCache: (RaceStateBlob) -> Void

    init(
        raceId: UUID,
        splitsPerLap: Int,
        onSaveSplit: @escaping (Split) -> Void,
        onDeleteSplit: @escaping (UUID) -> Void,
        onStageCache: @escaping (RaceStateBlob) -> Void
    ) {
        self.raceId = raceId
        self.splitsPerLap = splitsPerLap
        self.onSaveSplit = onSaveSplit
        self.onDeleteSplit = onDeleteSplit
        self.onStageCache = onStageCache
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: – Lifecycle

    func start(at date: Date, existingSplits: [Split] = []) {
        startedAt = date
        currentSplits = existingSplits
        attachDisplayLink()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func resume(from blob: RaceStateBlob) {
        unassignedMarks = blob.unassignedMarks
        undoStack = blob.undoStack
    }

    // MARK: – Display Link

    private func attachDisplayLink() {
        let dl = CADisplayLink(target: self, selector: #selector(tick))
        dl.add(to: .main, forMode: .common) // .common not .default — critical for scroll
        if #available(iOS 15.0, *) {
            dl.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        }
        displayLink = dl
    }

    @objc private func tick() {
        guard let start = startedAt else { return }
        elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
    }

    // MARK: – Mark Tap

    func handleMarkTap() {
        guard let start = startedAt else { return }
        let ts = Int(Date().timeIntervalSince(start) * 1000)
        let mark = UnassignedMark(raceId: raceId, timestampMs: ts)
        insertMark(mark)
        undoStack.append(.markCreated(markId: mark.id))
        stageCache()
        HapticEngine.heavy()
        assertQueueIntegrity()
    }

    // MARK: – Card Tap (FIFO assignment)

    func handleCardTap(athleteId: UUID) {
        guard let start = startedAt else { return }

        let consumedMark: UnassignedMark?
        let timestampMs: Int

        if !unassignedMarks.isEmpty {
            consumedMark = unassignedMarks.removeFirst()
            timestampMs = consumedMark!.timestampMs
        } else {
            consumedMark = nil
            timestampMs = Int(Date().timeIntervalSince(start) * 1000)
        }

        let existingSplitCount = currentSplits.filter { $0.athleteId == athleteId }.count
        let lap = RaceDomain.lapIndex(existingSplitCount: existingSplitCount, splitsPerLap: splitsPerLap)

        let split = Split(
            raceId: raceId,
            athleteId: athleteId,
            lapIndex: lap,
            elapsedMs: timestampMs
        )

        onSaveSplit(split)
        currentSplits.append(split)
        undoStack.append(.splitAssigned(splitId: split.id, consumedMarkId: consumedMark?.id))
        stageCache()
        HapticEngine.medium()
        assertQueueIntegrity()
    }

    // MARK: – Undo

    func undo() {
        guard let last = undoStack.last else { return }
        undoStack.removeLast()

        switch last {
        case .splitAssigned(let splitId, let consumedMarkId):
            // Capture elapsedMs before removal so we can restore the mark timestamp
            let originalTs = currentSplits.first { $0.id == splitId }?.elapsedMs ?? 0
            onDeleteSplit(splitId)
            currentSplits.removeAll { $0.id == splitId }
            if let markId = consumedMarkId {
                let mark = UnassignedMark(id: markId, raceId: raceId, timestampMs: originalTs)
                insertMark(mark)
            }

        case .markCreated(let markId):
            #if DEBUG
            let stillInQueue = unassignedMarks.contains { $0.id == markId }
            assert(stillInQueue, "Undoing markCreated for a consumed mark — stack corrupted")
            #endif
            unassignedMarks.removeAll { $0.id == markId }
        }

        stageCache()
        HapticEngine.rigid()
        assertQueueIntegrity()
    }

    // MARK: – Helpers

    private func insertMark(_ mark: UnassignedMark) {
        let idx = unassignedMarks
            .firstIndex { $0.timestampMs > mark.timestampMs }
            ?? unassignedMarks.endIndex
        unassignedMarks.insert(mark, at: idx)
    }

    private func stageCache() {
        let blob = RaceStateBlob(
            raceId: raceId,
            unassignedMarks: unassignedMarks,
            undoStack: undoStack,
            capturedAt: Date()
        )
        onStageCache(blob)
    }

    private func assertQueueIntegrity() {
        #if DEBUG
        assert(
            zip(unassignedMarks, unassignedMarks.dropFirst())
                .allSatisfy { $0.timestampMs <= $1.timestampMs },
            "Unassigned mark queue is out of order"
        )
        #endif
    }

    // MARK: – Split mirror accessor

    func splits(for athleteId: UUID) -> [Split] {
        currentSplits
            .filter { $0.athleteId == athleteId }
            .sorted { $0.lapIndex < $1.lapIndex }
    }

    var allCurrentSplits: [Split] { currentSplits }
}

// MARK: – Haptic Engine

private enum HapticEngine {
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
