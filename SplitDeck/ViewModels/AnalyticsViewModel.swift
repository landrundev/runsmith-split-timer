import Foundation
import Combine

@MainActor
final class AnalyticsViewModel: ObservableObject {

    // MARK: – Published State

    @Published var seasonStats = SeasonStats()
    @Published var prBoard: [PREntry] = []
    @Published var eventLeaderboard: [LeaderboardEntry] = []
    @Published var selectedEvent: EventType = .m800
    @Published var selectedGender: Gender? = nil
    @Published var athleteInsights: [AthleteInsight] = []
    @Published var raceHighlights: [RaceHighlight] = []
    @Published var isLoaded = false

    // MARK: – Cached Data (populated once in load, reused by refreshLeaderboard)

    private var cachedRaces: [Race] = []
    private var cachedAthletes: [Athlete] = []
    private var cachedSplitsByRace: [UUID: [Split]] = [:]

    private let store: SplitDeckStore

    init(store: SplitDeckStore) {
        self.store = store
    }

    // MARK: – Data Types

    struct SeasonStats {
        var totalRaces = 0
        var totalAthletes = 0
        var totalMeets = 0
        var totalSplitsRecorded = 0
        var firstRaceDate: Date? = nil
        var lastRaceDate: Date? = nil
    }

    enum TimeSourceFilter: String, CaseIterable {
        case all = "All"
        case race = "Race"
        case split = "Split"
    }

    struct PREntry: Identifiable {
        let id = UUID()
        let athlete: Athlete
        let eventType: EventType
        let prMs: Int
        let prDate: Date?
        let raceCount: Int
        let isSplit: Bool
    }

    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let rank: Int
        let athlete: Athlete
        let bestMs: Int
        let raceCount: Int
        let isSplit: Bool
    }

    struct AthleteInsight: Identifiable {
        let id = UUID()
        let athlete: Athlete
        let totalRaces: Int
        let bestEvent: EventType?
        let bestTimeMs: Int?
        let consistencyScore: Double?    // std dev of lap times in ms — lower = more consistent
        let negativeSplitRate: Double?   // fraction of eligible races with negative splits (0.0–1.0)
        let fastestLapMs: Int?
        let prTrend: [PRPoint]           // chronological PR progression for best event
    }

    struct PRPoint: Identifiable {
        let id = UUID()
        let date: Date
        let ms: Int
    }

    struct RaceHighlight: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let detail: String
        let icon: String  // SF Symbol name
    }

    // MARK: – Load All Data

    func load() {
        guard !isLoaded else { return }

        let athletes = (try? store.fetchAthletes()) ?? []
        let allRaces = (try? store.fetchAllCompletedRaces()) ?? []
        let meets = (try? store.fetchMeets()) ?? []

        // Prefetch all splits keyed by raceId
        var splitsByRace: [UUID: [Split]] = [:]
        for race in allRaces {
            splitsByRace[race.id] = (try? store.fetchSplits(for: race.id)) ?? []
        }

        // Cache for reuse by refreshLeaderboard
        cachedRaces = allRaces
        cachedAthletes = athletes
        cachedSplitsByRace = splitsByRace

        computeSeasonStats(races: allRaces, athletes: athletes, meets: meets, splitsByRace: splitsByRace)
        computePRBoard(races: allRaces, athletes: athletes, splitsByRace: splitsByRace)
        computeEventLeaderboard(races: allRaces, athletes: athletes, splitsByRace: splitsByRace)
        computeAthleteInsights(races: allRaces, athletes: athletes, splitsByRace: splitsByRace)
        computeRaceHighlights(races: allRaces, athletes: athletes, splitsByRace: splitsByRace)

        isLoaded = true
    }

    /// Call when selectedEvent or selectedGender changes. Uses cached data — no re-fetch.
    func refreshLeaderboard() {
        computeEventLeaderboard(
            races: cachedRaces,
            athletes: cachedAthletes,
            splitsByRace: cachedSplitsByRace
        )
    }

    // MARK: – Season Stats

    private func computeSeasonStats(
        races: [Race], athletes: [Athlete], meets: [Meet], splitsByRace: [UUID: [Split]]
    ) {
        var stats = SeasonStats()
        stats.totalRaces = races.count
        stats.totalAthletes = athletes.count
        stats.totalMeets = meets.count
        stats.totalSplitsRecorded = splitsByRace.values.reduce(0) { $0 + $1.count }

        let dates = races.compactMap(\.startedAt).sorted()
        stats.firstRaceDate = dates.first
        stats.lastRaceDate = dates.last

        seasonStats = stats
    }

    // MARK: – PR Board

    private func computePRBoard(
        races: [Race], athletes: [Athlete], splitsByRace: [UUID: [Split]]
    ) {
        var entries: [PREntry] = []

        for athlete in athletes {
            // Race PRs (final times)
            var eventBests: [EventType: (ms: Int, date: Date?, count: Int)] = [:]

            for race in races where race.athleteIds.contains(athlete.id) && !race.eventType.isRelay {
                let splits = splitsByRace[race.id] ?? []
                let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                    .sorted { $0.elapsedMs < $1.elapsedMs }

                guard let finalSplit = athleteSplits.last else { continue }

                let existing = eventBests[race.eventType]
                let count = (existing?.count ?? 0) + 1

                if existing == nil || finalSplit.elapsedMs < existing!.ms {
                    eventBests[race.eventType] = (finalSplit.elapsedMs, race.startedAt, count)
                } else {
                    eventBests[race.eventType] = (existing!.ms, existing!.date, count)
                }
            }

            for (event, best) in eventBests {
                entries.append(PREntry(
                    athlete: athlete,
                    eventType: event,
                    prMs: best.ms,
                    prDate: best.date,
                    raceCount: best.count,
                    isSplit: false
                ))
            }

            // Split PRs (lap-to-lap deltas from multi-split races)
            var splitBests: [EventType: (ms: Int, date: Date?, count: Int)] = [:]

            for race in races where race.athleteIds.contains(athlete.id) {
                guard race.expectedSplitsPerAthlete > 1 else { continue }

                let splitDist = race.trackLengthMeters / max(race.splitsPerLap, 1)
                guard let splitEvent = EventType.eventType(forSplitDistance: splitDist) else { continue }

                let splits = splitsByRace[race.id] ?? []

                if race.eventType.isRelay {
                    // Relay: get this athlete's leg splits
                    let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                        .sorted { $0.elapsedMs < $1.elapsedMs }
                    guard !athleteSplits.isEmpty else { continue }

                    // Find previous leg's cumulative
                    let legIndex = race.athleteIds.firstIndex(of: athlete.id) ?? 0
                    let prevCumulative: Int
                    if legIndex > 0 {
                        let prevId = race.athleteIds[legIndex - 1]
                        prevCumulative = splits.filter { $0.athleteId == prevId }
                            .map(\.elapsedMs).max() ?? 0
                    } else {
                        prevCumulative = 0
                    }

                    // Compute lap deltas within the leg
                    for (i, split) in athleteSplits.enumerated() {
                        let prev = i > 0 ? athleteSplits[i - 1].elapsedMs : prevCumulative
                        let lapMs = split.elapsedMs - prev
                        let existing = splitBests[splitEvent]
                        let count = (existing?.count ?? 0) + 1
                        if existing == nil || lapMs < existing!.ms {
                            splitBests[splitEvent] = (lapMs, race.startedAt, count)
                        } else {
                            splitBests[splitEvent] = (existing!.ms, existing!.date, count)
                        }
                    }
                } else {
                    // Individual: compute lap-to-lap deltas
                    let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                        .sorted { $0.elapsedMs < $1.elapsedMs }
                    guard athleteSplits.count > 1 else { continue }

                    var deltas: [Int] = []
                    for (i, split) in athleteSplits.enumerated() {
                        deltas.append(i == 0 ? split.elapsedMs : split.elapsedMs - athleteSplits[i - 1].elapsedMs)
                    }

                    // Drop last delta if race distance doesn't divide evenly by split distance
                    // (e.g. 1500m → last lap is 300m, not a real 400m split)
                    if !race.isUnlimitedSplits && race.distanceMeters > 0
                        && race.distanceMeters % splitDist != 0
                        && athleteSplits.count == race.expectedSplitsPerAthlete {
                        deltas.removeLast()
                    }

                    for lapMs in deltas {
                        let existing = splitBests[splitEvent]
                        let count = (existing?.count ?? 0) + 1
                        if existing == nil || lapMs < existing!.ms {
                            splitBests[splitEvent] = (lapMs, race.startedAt, count)
                        } else {
                            splitBests[splitEvent] = (existing!.ms, existing!.date, count)
                        }
                    }
                }
            }

            for (event, best) in splitBests {
                entries.append(PREntry(
                    athlete: athlete,
                    eventType: event,
                    prMs: best.ms,
                    prDate: best.date,
                    raceCount: best.count,
                    isSplit: true
                ))
            }
        }

        prBoard = entries.sorted {
            let order0 = Self.eventSortOrder($0.eventType)
            let order1 = Self.eventSortOrder($1.eventType)
            if order0 != order1 { return order0 < order1 }
            return $0.prMs < $1.prMs
        }
    }

    // MARK: – Event Leaderboard

    private func computeEventLeaderboard(
        races: [Race], athletes: [Athlete], splitsByRace: [UUID: [Split]]
    ) {
        let filteredAthletes: [Athlete]
        if let gender = selectedGender {
            filteredAthletes = athletes.filter { $0.gender == gender }
        } else {
            filteredAthletes = athletes
        }

        var bests: [(athlete: Athlete, ms: Int, count: Int, isSplit: Bool)] = []

        for athlete in filteredAthletes {
            // Race times (exact event match)
            let eventRaces = races.filter {
                $0.eventType == selectedEvent && $0.athleteIds.contains(athlete.id) && !$0.eventType.isRelay
            }

            var bestRaceMs = Int.max
            for race in eventRaces {
                let splits = splitsByRace[race.id] ?? []
                let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                if let final_ = athleteSplits.map(\.elapsedMs).max() {
                    bestRaceMs = min(bestRaceMs, final_)
                }
            }

            if bestRaceMs < Int.max {
                bests.append((athlete, bestRaceMs, eventRaces.count, false))
            }

            // Split times (from longer races where split distance matches selectedEvent)
            var bestSplitMs = Int.max
            var splitCount = 0

            for race in races where race.athleteIds.contains(athlete.id) && race.expectedSplitsPerAthlete > 1 {
                let splitDist = race.trackLengthMeters / max(race.splitsPerLap, 1)
                guard EventType.eventType(forSplitDistance: splitDist) == selectedEvent else { continue }

                let splits = splitsByRace[race.id] ?? []

                if race.eventType.isRelay {
                    let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                        .sorted { $0.elapsedMs < $1.elapsedMs }
                    guard !athleteSplits.isEmpty else { continue }

                    let legIndex = race.athleteIds.firstIndex(of: athlete.id) ?? 0
                    let prevCumulative: Int
                    if legIndex > 0 {
                        let prevId = race.athleteIds[legIndex - 1]
                        prevCumulative = splits.filter { $0.athleteId == prevId }
                            .map(\.elapsedMs).max() ?? 0
                    } else {
                        prevCumulative = 0
                    }

                    splitCount += 1
                    for (i, split) in athleteSplits.enumerated() {
                        let prev = i > 0 ? athleteSplits[i - 1].elapsedMs : prevCumulative
                        bestSplitMs = min(bestSplitMs, split.elapsedMs - prev)
                    }
                } else {
                    let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                        .sorted { $0.elapsedMs < $1.elapsedMs }
                    guard athleteSplits.count > 1 else { continue }

                    var deltas: [Int] = []
                    for (i, split) in athleteSplits.enumerated() {
                        deltas.append(i == 0 ? split.elapsedMs : split.elapsedMs - athleteSplits[i - 1].elapsedMs)
                    }

                    // Drop last delta if race distance doesn't divide evenly by split distance
                    if !race.isUnlimitedSplits && race.distanceMeters > 0
                        && race.distanceMeters % splitDist != 0
                        && athleteSplits.count == race.expectedSplitsPerAthlete {
                        deltas.removeLast()
                    }

                    splitCount += 1
                    for lapMs in deltas {
                        bestSplitMs = min(bestSplitMs, lapMs)
                    }
                }
            }

            if bestSplitMs < Int.max {
                bests.append((athlete, bestSplitMs, splitCount, true))
            }
        }

        bests.sort { $0.ms < $1.ms }

        eventLeaderboard = bests.enumerated().map { i, entry in
            LeaderboardEntry(
                rank: i + 1,
                athlete: entry.athlete,
                bestMs: entry.ms,
                raceCount: entry.count,
                isSplit: entry.isSplit
            )
        }
    }

    // MARK: – Athlete Insights

    private func computeAthleteInsights(
        races: [Race], athletes: [Athlete], splitsByRace: [UUID: [Split]]
    ) {
        var insights: [AthleteInsight] = []

        for athlete in athletes {
            let athleteRaces = races.filter { $0.athleteIds.contains(athlete.id) && !$0.eventType.isRelay }
            guard !athleteRaces.isEmpty else { continue }

            // Best event + time
            var eventBests: [EventType: Int] = [:]
            for race in athleteRaces {
                let splits = splitsByRace[race.id] ?? []
                let final_ = splits.filter { $0.athleteId == athlete.id }.map(\.elapsedMs).max()
                if let f = final_ {
                    if eventBests[race.eventType] == nil || f < eventBests[race.eventType]! {
                        eventBests[race.eventType] = f
                    }
                }
            }
            let bestEvent = eventBests.min(by: { $0.value < $1.value })

            // Consistency score — average std dev of lap-to-lap times across races
            var allLapStdDevs: [Double] = []
            for race in athleteRaces {
                let splits = splitsByRace[race.id] ?? []
                let lapTimes = computeLapTimes(athleteId: athlete.id, splits: splits)
                if lapTimes.count >= 2 {
                    allLapStdDevs.append(standardDeviation(lapTimes.map { Double($0) }))
                }
            }
            let avgConsistency = allLapStdDevs.isEmpty ? nil : allLapStdDevs.reduce(0, +) / Double(allLapStdDevs.count)

            // Negative split rate — only count races with an even number of laps
            // so the first-half vs second-half comparison is fair
            var negativeSplitCount = 0
            var eligibleRaceCount = 0
            for race in athleteRaces {
                let splits = splitsByRace[race.id] ?? []
                let lapTimes = computeLapTimes(athleteId: athlete.id, splits: splits)
                guard lapTimes.count >= 2 && lapTimes.count.isMultiple(of: 2) else { continue }
                eligibleRaceCount += 1
                let half = lapTimes.count / 2
                let firstHalf = lapTimes[0..<half].reduce(0, +)
                let secondHalf = lapTimes[half...].reduce(0, +)
                if secondHalf < firstHalf { negativeSplitCount += 1 }
            }
            let negSplitRate = eligibleRaceCount > 0 ? Double(negativeSplitCount) / Double(eligibleRaceCount) : nil

            // Fastest single lap
            var fastestLap: Int? = nil
            for race in athleteRaces {
                let splits = splitsByRace[race.id] ?? []
                let lapTimes = computeLapTimes(athleteId: athlete.id, splits: splits)
                if let minLap = lapTimes.min() {
                    if fastestLap == nil || minLap < fastestLap! { fastestLap = minLap }
                }
            }

            // PR trend for best event
            var prTrend: [PRPoint] = []
            if let bestEvt = bestEvent?.key {
                let eventRaces = athleteRaces
                    .filter { $0.eventType == bestEvt }
                    .sorted { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }

                var runningPR = Int.max
                for race in eventRaces {
                    let splits = splitsByRace[race.id] ?? []
                    let final_ = splits.filter { $0.athleteId == athlete.id }.map(\.elapsedMs).max()
                    if let f = final_, let date = race.startedAt {
                        runningPR = min(runningPR, f)
                        prTrend.append(PRPoint(date: date, ms: runningPR))
                    }
                }
            }

            insights.append(AthleteInsight(
                athlete: athlete,
                totalRaces: athleteRaces.count,
                bestEvent: bestEvent?.key,
                bestTimeMs: bestEvent?.value,
                consistencyScore: avgConsistency,
                negativeSplitRate: negSplitRate,
                fastestLapMs: fastestLap,
                prTrend: prTrend
            ))
        }

        athleteInsights = insights.sorted { $0.totalRaces > $1.totalRaces }
    }

    // MARK: – Race Highlights

    private func computeRaceHighlights(
        races: [Race], athletes: [Athlete], splitsByRace: [UUID: [Split]]
    ) {
        var highlights: [RaceHighlight] = []

        // Closest finish — smallest gap between 1st and 2nd place final time
        var closestGap: (race: Race, gap: Int, first: Athlete, second: Athlete)? = nil
        for race in races where !race.eventType.isRelay {
            let splits = splitsByRace[race.id] ?? []
            let finishTimes: [(athlete: Athlete, ms: Int)] = race.athleteIds.compactMap { id in
                guard let a = athletes.first(where: { $0.id == id }) else { return nil }
                let final_ = splits.filter { $0.athleteId == id }.map(\.elapsedMs).max()
                guard let f = final_ else { return nil }
                return (a, f)
            }.sorted { $0.ms < $1.ms }

            if finishTimes.count >= 2 {
                let gap = finishTimes[1].ms - finishTimes[0].ms
                if closestGap == nil || gap < closestGap!.gap {
                    closestGap = (race, gap, finishTimes[0].athlete, finishTimes[1].athlete)
                }
            }
        }
        if let c = closestGap {
            highlights.append(RaceHighlight(
                title: "Closest Finish",
                subtitle: c.race.name,
                detail: "\(c.first.name) beat \(c.second.name) by \(c.gap.formattedSplitTime)",
                icon: "flame"
            ))
        }

        // Biggest PR drop — largest improvement in a single event
        var biggestDrop: (athlete: Athlete, event: EventType, dropMs: Int)? = nil
        for athlete in athletes {
            let athleteRaces = races.filter {
                $0.athleteIds.contains(athlete.id) && !$0.eventType.isRelay
            }.sorted { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }

            var eventFirstLast: [EventType: (first: Int, best: Int)] = [:]
            for race in athleteRaces {
                let splits = splitsByRace[race.id] ?? []
                let final_ = splits.filter { $0.athleteId == athlete.id }.map(\.elapsedMs).max()
                guard let f = final_ else { continue }
                if eventFirstLast[race.eventType] == nil {
                    eventFirstLast[race.eventType] = (f, f)
                } else {
                    eventFirstLast[race.eventType]!.best = min(eventFirstLast[race.eventType]!.best, f)
                }
            }

            for (event, data) in eventFirstLast {
                let drop = data.first - data.best
                if drop > 0 && (biggestDrop == nil || drop > biggestDrop!.dropMs) {
                    biggestDrop = (athlete, event, drop)
                }
            }
        }
        if let d = biggestDrop {
            highlights.append(RaceHighlight(
                title: "Biggest PR Drop",
                subtitle: "\(d.athlete.name) — \(d.event.displayName)",
                detail: "Improved by \(d.dropMs.formattedSplitTime)",
                icon: "arrow.down.right"
            ))
        }

        // Most raced athlete
        let raceCounts: [(athlete: Athlete, count: Int)] = athletes.map { athlete in
            let count = races.filter { $0.athleteIds.contains(athlete.id) }.count
            return (athlete, count)
        }.sorted { $0.count > $1.count }

        if let top = raceCounts.first, top.count > 0 {
            highlights.append(RaceHighlight(
                title: "Most Raced",
                subtitle: top.athlete.name,
                detail: "\(top.count) race\(top.count == 1 ? "" : "s") completed",
                icon: "figure.run"
            ))
        }

        // Fastest single lap ever
        var fastestEver: (athlete: Athlete, race: Race, lapMs: Int)? = nil
        for race in races where !race.eventType.isRelay {
            let splits = splitsByRace[race.id] ?? []
            for athleteId in race.athleteIds {
                let lapTimes = computeLapTimes(athleteId: athleteId, splits: splits)
                if let minLap = lapTimes.min() {
                    if fastestEver == nil || minLap < fastestEver!.lapMs {
                        if let a = athletes.first(where: { $0.id == athleteId }) {
                            fastestEver = (a, race, minLap)
                        }
                    }
                }
            }
        }
        if let f = fastestEver {
            highlights.append(RaceHighlight(
                title: "Fastest Lap Ever",
                subtitle: f.athlete.name,
                detail: "\(f.lapMs.formattedSplitTime) in \(f.race.name)",
                icon: "bolt"
            ))
        }

        raceHighlights = highlights
    }

    // MARK: – Helpers

    /// Distance-based sort index: 400 → 800 → 1500 → Mile → 1600 → 3200 → 5K → 10K → Custom last.
    private static let distanceSortOrder: [EventType] = [
        .m100, .m200, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000, .custom
    ]

    static func eventSortOrder(_ event: EventType) -> Int {
        distanceSortOrder.firstIndex(of: event) ?? distanceSortOrder.count
    }

    /// Returns lap-by-lap split times (not cumulative) for one athlete in one race.
    private func computeLapTimes(athleteId: UUID, splits: [Split]) -> [Int] {
        let sorted = splits.filter { $0.athleteId == athleteId }
            .sorted { $0.elapsedMs < $1.elapsedMs }
        guard !sorted.isEmpty else { return [] }

        var lapTimes: [Int] = []
        var prev = 0
        for split in sorted {
            lapTimes.append(split.elapsedMs - prev)
            prev = split.elapsedMs
        }
        return lapTimes
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
