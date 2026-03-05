import Foundation

// MARK: – CellValue

enum CellValue {
    case time(Int)  // elapsedMs — renders as formatted time
    case missing    // renders as "—"

    var displayString: String {
        switch self {
        case .time(let ms): return ms.formattedSplitTime
        case .missing:      return "\u{2014}"
        }
    }
}

// MARK: – RaceDomain

enum RaceDomain {

    // MARK: Lap index from count of existing splits for one athlete
    static func lapIndex(existingSplitCount: Int, splitsPerLap: Int) -> Int {
        Int(ceil(Double(existingSplitCount + 1) / Double(splitsPerLap)))
    }

    // MARK: Highest lap shown in the "Lap X of Y" header
    static func currentDisplayLap(splits: [Split], race: Race) -> Int {
        let maxCompleted = splits.map(\.lapIndex).max() ?? 0
        if race.isUnlimitedSplits { return maxCompleted + 1 }
        return min(maxCompleted + 1, race.laps)
    }

    // MARK: A valid final time exists ONLY if lapIndex == race.laps exists for athlete
    static func finalTime(athlete: Athlete, splits: [Split], race: Race) -> Int? {
        guard !race.isUnlimitedSplits else { return nil }
        return splits.first {
            $0.athleteId == athlete.id && $0.lapIndex == race.laps
        }?.elapsedMs
    }

    static func isComplete(athlete: Athlete, splits: [Split], race: Race) -> Bool {
        finalTime(athlete: athlete, splits: splits, race: race) != nil
    }

    // MARK: Last recorded lap for an athlete (drives the "show vs. dash" cutoff)
    static func lastRecordedLap(athlete: Athlete, splits: [Split]) -> Int? {
        splits.filter { $0.athleteId == athlete.id }.map(\.lapIndex).max()
    }

    // MARK: Lap time = difference from previous split (or from start for lap 1)
    static func lapTime(athlete: Athlete, lapIndex: Int, splits: [Split]) -> Int? {
        let s = splits
            .filter { $0.athleteId == athlete.id }
            .sorted { $0.lapIndex < $1.lapIndex }
        guard let cur = s.first(where: { $0.lapIndex == lapIndex }) else { return nil }
        let prev = s.first(where: { $0.lapIndex == lapIndex - 1 })
        return cur.elapsedMs - (prev?.elapsedMs ?? 0)
    }

    // MARK: Athletes sorted: complete by finalTime asc, incomplete appended at bottom
    // Returns optional place — incomplete athletes get nil (display as "—")
    static func ranked(
        athletes: [Athlete],
        splits: [Split],
        race: Race
    ) -> [(athlete: Athlete, place: Int?)] {
        if race.isUnlimitedSplits {
            // Unlimited: sort by split count desc, then last time asc
            let sorted = athletes.sorted { a, b in
                let aCount = splits.filter { $0.athleteId == a.id }.count
                let bCount = splits.filter { $0.athleteId == b.id }.count
                if aCount != bCount { return aCount > bCount }
                let aMax = splits.filter { $0.athleteId == a.id }.map(\.elapsedMs).max() ?? 0
                let bMax = splits.filter { $0.athleteId == b.id }.map(\.elapsedMs).max() ?? 0
                return aMax < bMax
            }
            return sorted.map { (athlete: $0, place: nil as Int?) }
        }
        let complete = athletes
            .filter { isComplete(athlete: $0, splits: splits, race: race) }
            .sorted {
                finalTime(athlete: $0, splits: splits, race: race)!
                    < finalTime(athlete: $1, splits: splits, race: race)!
            }
        let incomplete = athletes
            .filter { !isComplete(athlete: $0, splits: splits, race: race) }
        let placed   = complete.enumerated().map { (athlete: $1, place: $0 + 1) }
        let unplaced = incomplete.map { (athlete: $0, place: nil as Int?) }
        return placed + unplaced
    }

    // MARK: Dynamic column labels for any race — no hardcoding for 1600/3200
    static func cumulativeColumnLabels(for race: Race, splits: [Split] = []) -> [String] {
        if race.isUnlimitedSplits {
            let maxCount = Dictionary(grouping: splits, by: \.athleteId)
                .values.map(\.count).max() ?? 0
            guard maxCount > 0 else { return [] }
            return (1...maxCount).map { "Split \($0)" }
        }
        let totalColumns = race.laps * race.splitsPerLap
        let splitDistance = race.trackLengthMeters / race.splitsPerLap
        return (1...totalColumns).map { "\(splitDistance * $0)m" }
    }

    // MARK: Ordinal-based cell values (used by Results + CSV)
    // Splits sorted by elapsed time; ordinal = 1-based position in that sorted list.

    static func cumulativeDisplayByOrdinal(
        athlete: Athlete, splitOrdinal: Int, splits: [Split], race: Race
    ) -> CellValue {
        let sorted = splits.filter { $0.athleteId == athlete.id }
            .sorted { $0.elapsedMs < $1.elapsedMs }
        guard splitOrdinal >= 1, splitOrdinal <= sorted.count else { return .missing }
        return .time(sorted[splitOrdinal - 1].elapsedMs)
    }

    static func lapTimeDisplayByOrdinal(
        athlete: Athlete, splitOrdinal: Int, splits: [Split], race: Race
    ) -> CellValue {
        let sorted = splits.filter { $0.athleteId == athlete.id }
            .sorted { $0.elapsedMs < $1.elapsedMs }
        guard splitOrdinal >= 1, splitOrdinal <= sorted.count else { return .missing }
        let cur = sorted[splitOrdinal - 1].elapsedMs
        let prev = splitOrdinal > 1 ? sorted[splitOrdinal - 2].elapsedMs : 0
        return .time(cur - prev)
    }

    // MARK: Legacy lapIndex-based cell values (used by live timing, backwards compat for splitsPerLap==1)
    static func cumulativeDisplay(
        athlete: Athlete, lapIndex: Int, splits: [Split], race: Race
    ) -> CellValue {
        let recorded = lastRecordedLap(athlete: athlete, splits: splits) ?? 0
        guard lapIndex <= recorded else { return .missing }
        if let s = splits.first(where: {
            $0.athleteId == athlete.id && $0.lapIndex == lapIndex
        }) {
            return .time(s.elapsedMs)
        }
        return .missing
    }

    static func lapTimeDisplay(
        athlete: Athlete, lapIndex: Int, splits: [Split], race: Race
    ) -> CellValue {
        let recorded = lastRecordedLap(athlete: athlete, splits: splits) ?? 0
        guard lapIndex <= recorded else { return .missing }
        if let ms = lapTime(athlete: athlete, lapIndex: lapIndex, splits: splits) {
            return .time(ms)
        }
        return .missing
    }

    // MARK: Relay leg breakdown — athletes must be in leg order (index 0 = leg 1)
    static func relayLegData(
        athletes: [Athlete],
        splits: [Split],
        race: Race
    ) -> [(leg: Int, athlete: Athlete, legMs: Int?, cumulativeMs: Int?)] {
        athletes.enumerated().map { i, athlete in
            let cumulative = splits.first { $0.athleteId == athlete.id }?.elapsedMs
            let previousCumulative: Int? = i > 0
                ? splits.first { $0.athleteId == athletes[i - 1].id }?.elapsedMs
                : nil
            let legMs: Int? = cumulative.map { $0 - (previousCumulative ?? 0) }
            return (leg: i + 1, athlete: athlete, legMs: legMs, cumulativeMs: cumulative)
        }
    }
}
