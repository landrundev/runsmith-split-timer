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
        return min(maxCompleted + 1, race.laps)
    }

    // MARK: A valid final time exists ONLY if lapIndex == race.laps exists for athlete
    static func finalTime(athlete: Athlete, splits: [Split], race: Race) -> Int? {
        splits.first {
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
    static func cumulativeColumnLabels(for race: Race) -> [String] {
        let lapDistance = race.distanceMeters / race.laps // integer division
        return (1...race.laps).map { "\(lapDistance * $0)m" }
    }

    // MARK: Cell value for results table (both display and CSV share this path)
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
