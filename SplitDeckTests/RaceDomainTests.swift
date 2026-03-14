import XCTest
@testable import RunsmithSplitTimer

final class RaceDomainTests: XCTestCase {

    // MARK: – Helpers

    private func makeAthlete(id: UUID = UUID(), name: String = "Test") -> Athlete {
        Athlete(id: id, name: name, colorHex: "#FF0000", gender: .male)
    }

    private func makeSplit(
        raceId: UUID = UUID(),
        athleteId: UUID,
        lapIndex: Int,
        elapsedMs: Int
    ) -> Split {
        Split(raceId: raceId, athleteId: athleteId, lapIndex: lapIndex, elapsedMs: elapsedMs)
    }

    private func makeRace(
        id: UUID = UUID(),
        eventType: EventType = .m1600,
        distanceMeters: Int = 1600,
        trackLengthMeters: Int = 400,
        splitsPerLap: Int = 1,
        isUnlimitedSplits: Bool = false,
        athleteIds: [UUID] = []
    ) -> Race {
        Race(
            id: id, name: "Test Race", eventType: eventType,
            distanceMeters: distanceMeters, trackLengthMeters: trackLengthMeters,
            splitsPerLap: splitsPerLap, isUnlimitedSplits: isUnlimitedSplits,
            athleteIds: athleteIds, status: .completed
        )
    }

    // MARK: – lapIndex(existingSplitCount:splitsPerLap:)

    func testLapIndex_splitsPerLap1() {
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 0, splitsPerLap: 1), 1)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 1, splitsPerLap: 1), 2)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 2, splitsPerLap: 1), 3)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 3, splitsPerLap: 1), 4)
    }

    func testLapIndex_splitsPerLap2() {
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 0, splitsPerLap: 2), 1)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 1, splitsPerLap: 2), 1)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 2, splitsPerLap: 2), 2)
        XCTAssertEqual(RaceDomain.lapIndex(existingSplitCount: 3, splitsPerLap: 2), 2)
    }

    // MARK: – finalTime(athlete:splits:race:)

    func testFinalTime_noSplitAtFinalLap_returnsNil() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id]) // 1600m, 4 laps
        // Only 3 splits — missing lap 4
        let splits = (1...3).map { makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: $0, elapsedMs: $0 * 60000) }
        XCTAssertNil(RaceDomain.finalTime(athlete: athlete, splits: splits, race: race))
    }

    func testFinalTime_withFinalLapSplit_returnsElapsedMs() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id]) // 1600m, 4 laps
        let splits = (1...4).map { makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: $0, elapsedMs: $0 * 60000) }
        XCTAssertEqual(RaceDomain.finalTime(athlete: athlete, splits: splits, race: race), 240000)
    }

    func testFinalTime_unlimitedSplits_returnsNil() {
        let athlete = makeAthlete()
        let race = makeRace(isUnlimitedSplits: true, athleteIds: [athlete.id])
        let splits = [makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: 1, elapsedMs: 60000)]
        XCTAssertNil(RaceDomain.finalTime(athlete: athlete, splits: splits, race: race))
    }

    // MARK: – isComplete(athlete:splits:race:)

    func testIsComplete_missingFinalLap_false() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id])
        let splits = (1...3).map { makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: $0, elapsedMs: $0 * 60000) }
        XCTAssertFalse(RaceDomain.isComplete(athlete: athlete, splits: splits, race: race))
    }

    func testIsComplete_withFinalLap_true() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id])
        let splits = (1...4).map { makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: $0, elapsedMs: $0 * 60000) }
        XCTAssertTrue(RaceDomain.isComplete(athlete: athlete, splits: splits, race: race))
    }

    // MARK: – ranked(athletes:splits:race:)

    func testRanked_completeSortedByFinalTime() {
        let a = makeAthlete(name: "Alice")
        let b = makeAthlete(name: "Bob")
        let race = makeRace(
            distanceMeters: 800, trackLengthMeters: 400,
            athleteIds: [a.id, b.id]
        ) // 2 laps
        let splits = [
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 1, elapsedMs: 60000),
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 2, elapsedMs: 130000),
            makeSplit(raceId: race.id, athleteId: b.id, lapIndex: 1, elapsedMs: 58000),
            makeSplit(raceId: race.id, athleteId: b.id, lapIndex: 2, elapsedMs: 120000),
        ]
        let result = RaceDomain.ranked(athletes: [a, b], splits: splits, race: race)
        XCTAssertEqual(result[0].athlete.id, b.id)
        XCTAssertEqual(result[0].place, 1)
        XCTAssertEqual(result[1].athlete.id, a.id)
        XCTAssertEqual(result[1].place, 2)
    }

    func testRanked_incompleteAppendedWithNilPlace() {
        let a = makeAthlete(name: "Alice")
        let b = makeAthlete(name: "Bob")
        let race = makeRace(
            distanceMeters: 800, trackLengthMeters: 400,
            athleteIds: [a.id, b.id]
        )
        let splits = [
            // Alice completes both laps
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 1, elapsedMs: 60000),
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 2, elapsedMs: 120000),
            // Bob only completes lap 1
            makeSplit(raceId: race.id, athleteId: b.id, lapIndex: 1, elapsedMs: 58000),
        ]
        let result = RaceDomain.ranked(athletes: [a, b], splits: splits, race: race)
        XCTAssertEqual(result[0].athlete.id, a.id)
        XCTAssertEqual(result[0].place, 1)
        XCTAssertEqual(result[1].athlete.id, b.id)
        XCTAssertNil(result[1].place)
    }

    func testRanked_identicalTimesRetainOriginalOrder() {
        let a = makeAthlete(name: "Alice")
        let b = makeAthlete(name: "Bob")
        let race = makeRace(
            distanceMeters: 800, trackLengthMeters: 400,
            athleteIds: [a.id, b.id]
        )
        let splits = [
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 1, elapsedMs: 60000),
            makeSplit(raceId: race.id, athleteId: a.id, lapIndex: 2, elapsedMs: 120000),
            makeSplit(raceId: race.id, athleteId: b.id, lapIndex: 1, elapsedMs: 60000),
            makeSplit(raceId: race.id, athleteId: b.id, lapIndex: 2, elapsedMs: 120000),
        ]
        // Pass [a, b] — stable sort should keep Alice first
        let result = RaceDomain.ranked(athletes: [a, b], splits: splits, race: race)
        XCTAssertEqual(result[0].athlete.id, a.id)
        XCTAssertEqual(result[0].place, 1)
        XCTAssertEqual(result[1].athlete.id, b.id)
        XCTAssertEqual(result[1].place, 2)
    }

    // MARK: – cumulativeColumnLabels(for:)

    func testCumulativeColumnLabels_1600m_4laps() {
        let race = makeRace(distanceMeters: 1600, trackLengthMeters: 400)
        let labels = RaceDomain.cumulativeColumnLabels(for: race)
        XCTAssertEqual(labels, ["400m", "800m", "1200m", "1600m"])
    }

    func testCumulativeColumnLabels_3200m_8laps() {
        let race = makeRace(distanceMeters: 3200, trackLengthMeters: 400)
        let labels = RaceDomain.cumulativeColumnLabels(for: race)
        XCTAssertEqual(labels.count, 8)
        XCTAssertEqual(labels.first, "400m")
        XCTAssertEqual(labels.last, "3200m")
    }

    func testCumulativeColumnLabels_unlimited_noSplits_empty() {
        let race = makeRace(isUnlimitedSplits: true)
        let labels = RaceDomain.cumulativeColumnLabels(for: race, splits: [])
        XCTAssertTrue(labels.isEmpty)
    }

    // MARK: – cumulativeDisplay(athlete:lapIndex:splits:race:)

    func testCumulativeDisplay_completedLap_returnsTime() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id])
        let splits = [makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: 1, elapsedMs: 62500)]
        let result = RaceDomain.cumulativeDisplay(athlete: athlete, lapIndex: 1, splits: splits, race: race)
        if case .time(let ms) = result {
            XCTAssertEqual(ms, 62500)
        } else {
            XCTFail("Expected .time, got .missing")
        }
    }

    func testCumulativeDisplay_beyondLastRecordedLap_returnsMissing() {
        let athlete = makeAthlete()
        let race = makeRace(athleteIds: [athlete.id])
        let splits = [makeSplit(raceId: race.id, athleteId: athlete.id, lapIndex: 1, elapsedMs: 62500)]
        let result = RaceDomain.cumulativeDisplay(athlete: athlete, lapIndex: 2, splits: splits, race: race)
        if case .missing = result {
            // expected
        } else {
            XCTFail("Expected .missing, got .time")
        }
    }
}
