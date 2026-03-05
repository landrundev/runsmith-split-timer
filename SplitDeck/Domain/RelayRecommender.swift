import Foundation

struct AthleteRelayCandidate: Identifiable {
    let id: UUID // athlete.id
    let athlete: Athlete
    let bestTimeMs: Int
    let source: TimeSource

    enum TimeSource {
        case individualPB(raceId: UUID)
        case splitFromRace(raceId: UUID, lapIndex: Int)
        case average(count: Int)
    }
}

enum RelayRecommender {

    static let supportedRelayTypes: [EventType] = [
        .relay4x400, .relay4x800, .relay4x1600, .relay4x3200
    ]

    /// Rank athletes for a relay event by their best time at the leg distance.
    ///
    /// Two-tier lookup per athlete:
    /// 1. **Individual PB** — completed non-relay, non-unlimited race where
    ///    `distanceMeters == legDistanceMeters`.  Uses `RaceDomain.finalTime`.
    /// 2. **Split fallback** — completed non-relay, non-unlimited race where each
    ///    lap covers the leg distance (`distanceMeters / laps == legDistance`).
    ///    Uses best `RaceDomain.lapTime` across all matching laps.
    ///
    /// Relay race data is never used — split times from relay legs are excluded.
    static func rankCandidates(
        relayEventType: EventType,
        gender: Gender,
        athletes: [Athlete],
        races: [Race],
        splitsByRaceId: [UUID: [Split]]
    ) -> [AthleteRelayCandidate] {
        guard let legDistance = relayEventType.legDistanceMeters else { return [] }

        let eligible = athletes.filter { $0.gender == gender }
        var candidates: [AthleteRelayCandidate] = []

        for athlete in eligible {
            if let candidate = bestTime(
                for: athlete,
                legDistanceMeters: legDistance,
                races: races,
                splitsByRaceId: splitsByRaceId
            ) {
                candidates.append(candidate)
            }
        }

        return candidates.sorted { $0.bestTimeMs < $1.bestTimeMs }
    }

    /// Suggest leg order for 4 chosen athletes.
    /// Strategy: Leg 1 = 2nd fastest, Leg 2 = 3rd, Leg 3 = slowest, Leg 4 (anchor) = fastest.
    static func suggestLegOrder(_ chosen: [AthleteRelayCandidate]) -> [AthleteRelayCandidate] {
        guard chosen.count == 4 else { return chosen }
        let sorted = chosen.sorted { $0.bestTimeMs < $1.bestTimeMs }
        // sorted[0]=fastest, sorted[1]=2nd, sorted[2]=3rd, sorted[3]=slowest
        return [sorted[1], sorted[2], sorted[3], sorted[0]]
    }

    // MARK: - Private

    private static func bestTime(
        for athlete: Athlete,
        legDistanceMeters: Int,
        races: [Race],
        splitsByRaceId: [UUID: [Split]]
    ) -> AthleteRelayCandidate? {

        // Tier 1: Individual race PB at exact distance
        var bestPBMs: Int?
        var bestPBRaceId: UUID?

        for race in races {
            guard !race.eventType.isRelay,
                  race.eventType != .custom,
                  !race.isUnlimitedSplits,
                  race.splitsPerLap == 1,
                  race.status == .completed,
                  race.athleteIds.contains(athlete.id),
                  race.distanceMeters == legDistanceMeters else { continue }

            let splits = splitsByRaceId[race.id] ?? []
            if let time = RaceDomain.finalTime(athlete: athlete, splits: splits, race: race) {
                if bestPBMs == nil || time < bestPBMs! {
                    bestPBMs = time
                    bestPBRaceId = race.id
                }
            }
        }

        if let ms = bestPBMs, let raceId = bestPBRaceId {
            return AthleteRelayCandidate(
                id: athlete.id,
                athlete: athlete,
                bestTimeMs: ms,
                source: .individualPB(raceId: raceId)
            )
        }

        // Tier 2: Best matching-distance split (lap time) from any individual race
        var bestSplitMs: Int?
        var bestSplitRaceId: UUID?
        var bestSplitLapIndex: Int?

        for race in races {
            guard !race.eventType.isRelay,
                  race.eventType != .custom,
                  !race.isUnlimitedSplits,
                  race.splitsPerLap == 1,
                  race.status == .completed,
                  race.athleteIds.contains(athlete.id) else { continue }

            let lapDistance = race.distanceMeters / race.laps
            guard lapDistance == legDistanceMeters else { continue }

            let splits = splitsByRaceId[race.id] ?? []

            for lapIdx in 1...race.laps {
                if let lapTime = RaceDomain.lapTime(athlete: athlete, lapIndex: lapIdx, splits: splits) {
                    if bestSplitMs == nil || lapTime < bestSplitMs! {
                        bestSplitMs = lapTime
                        bestSplitRaceId = race.id
                        bestSplitLapIndex = lapIdx
                    }
                }
            }
        }

        if let ms = bestSplitMs, let raceId = bestSplitRaceId, let lapIdx = bestSplitLapIndex {
            return AthleteRelayCandidate(
                id: athlete.id,
                athlete: athlete,
                bestTimeMs: ms,
                source: .splitFromRace(raceId: raceId, lapIndex: lapIdx)
            )
        }

        return nil
    }

    // MARK: - Average ranking

    /// Rank athletes by their average time at the leg distance.
    /// Collects every matching time per athlete (PBs + splits), averages them.
    static func rankCandidatesByAverage(
        relayEventType: EventType,
        gender: Gender,
        athletes: [Athlete],
        races: [Race],
        splitsByRaceId: [UUID: [Split]]
    ) -> [AthleteRelayCandidate] {
        guard let legDistance = relayEventType.legDistanceMeters else { return [] }

        let eligible = athletes.filter { $0.gender == gender }
        var candidates: [AthleteRelayCandidate] = []

        for athlete in eligible {
            let times = allTimes(
                for: athlete,
                legDistanceMeters: legDistance,
                races: races,
                splitsByRaceId: splitsByRaceId
            )
            guard !times.isEmpty else { continue }
            let avg = times.reduce(0, +) / times.count
            candidates.append(AthleteRelayCandidate(
                id: athlete.id,
                athlete: athlete,
                bestTimeMs: avg,
                source: .average(count: times.count)
            ))
        }

        return candidates.sorted { $0.bestTimeMs < $1.bestTimeMs }
    }

    private static func allTimes(
        for athlete: Athlete,
        legDistanceMeters: Int,
        races: [Race],
        splitsByRaceId: [UUID: [Split]]
    ) -> [Int] {
        var times: [Int] = []

        for race in races {
            guard !race.eventType.isRelay,
                  race.eventType != .custom,
                  !race.isUnlimitedSplits,
                  race.splitsPerLap == 1,
                  race.status == .completed,
                  race.athleteIds.contains(athlete.id) else { continue }

            let splits = splitsByRaceId[race.id] ?? []

            // Tier 1: exact distance match → final time
            if race.distanceMeters == legDistanceMeters {
                if let time = RaceDomain.finalTime(athlete: athlete, splits: splits, race: race) {
                    times.append(time)
                }
                continue // don't double-count laps from this race
            }

            // Tier 2: matching lap distance → all lap times
            let lapDistance = race.distanceMeters / race.laps
            guard lapDistance == legDistanceMeters else { continue }

            for lapIdx in 1...race.laps {
                if let lapTime = RaceDomain.lapTime(athlete: athlete, lapIndex: lapIdx, splits: splits) {
                    times.append(lapTime)
                }
            }
        }

        return times
    }
}
