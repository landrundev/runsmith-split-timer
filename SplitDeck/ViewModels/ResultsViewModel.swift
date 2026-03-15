import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable {
    case cumulative = "Cumulative"
    case lapTimes   = "Lap Times"
}


@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var displayMode: DisplayMode = .cumulative
    @Published private(set) var race: Race
    @Published private(set) var splits: [Split]

    let athletes: [Athlete]
    let meet: Meet?

    init(race: Race, athletes: [Athlete], splits: [Split], meet: Meet?) {
        self.race = race
        self.athletes = athletes
        self.splits = splits
        self.meet = meet
    }

    /// Reloads race and split data from the store. Call after official time entry
    /// or race info edits so the results screen reflects the latest state.
    func reload(store: SplitDeckStore) {
        if let updatedRace = try? store.fetchRace(id: race.id) {
            self.race = updatedRace
        }
        if let updatedSplits = try? store.fetchSplits(for: race.id) {
            self.splits = updatedSplits
        }
    }

    var orderedAthletes: [Athlete] {
        race.athleteIds.compactMap { id in athletes.first { $0.id == id } }
    }

    var rankedAthletes: [(athlete: Athlete, place: Int?)] {
        RaceDomain.ranked(athletes: orderedAthletes, splits: splits, race: race)
    }

    // MARK: – Relay

    var relayLegData: [(leg: Int, athlete: Athlete, legMs: Int?, cumulativeMs: Int?)] {
        guard race.eventType.isRelay else { return [] }
        return RaceDomain.relayLegData(athletes: orderedAthletes, splits: splits, race: race)
    }

    var totalRelayMs: Int? {
        relayLegData.last?.cumulativeMs
    }

    var columnLabels: [String] {
        RaceDomain.cumulativeColumnLabels(for: race, splits: splits)
    }

    func cellValue(athlete: Athlete, splitOrdinal: Int) -> CellValue {
        switch displayMode {
        case .cumulative:
            return RaceDomain.cumulativeDisplayByOrdinal(
                athlete: athlete, splitOrdinal: splitOrdinal, splits: splits, race: race)
        case .lapTimes:
            return RaceDomain.lapTimeDisplayByOrdinal(
                athlete: athlete, splitOrdinal: splitOrdinal, splits: splits, race: race)
        }
    }

    /// Always returns the cumulative total time regardless of display mode — used for the header row.
    func totalTimeValue(athlete: Athlete) -> CellValue {
        if race.isUnlimitedSplits {
            let athleteSplits = splits.filter { $0.athleteId == athlete.id }
                .sorted { $0.elapsedMs < $1.elapsedMs }
            guard let last = athleteSplits.last else { return .missing }
            return .time(last.elapsedMs)
        }
        let totalSplits = race.expectedSplitsPerAthlete
        return RaceDomain.cumulativeDisplayByOrdinal(
            athlete: athlete, splitOrdinal: totalSplits, splits: splits, race: race)
    }

    func exportCSV() -> String {
        CSVExporter.export(
            race: race,
            rankedAthletes: rankedAthletes,
            splits: splits,
            meet: meet
        )
    }

    func csvFilename() -> String {
        CSVExporter.filename(race: race, meet: meet)
    }

    func buildCardData() -> CardData {
        let labels = columnLabels
        let athleteRows = rankedAthletes.map { entry in
            let splitStrings = labels.indices.map { i in
                cellValue(athlete: entry.athlete, splitOrdinal: i + 1).displayString
            }
            return CardData.CardAthlete(
                name: entry.athlete.name,
                colorHex: entry.athlete.colorHex,
                place: entry.place,
                totalTime: totalTimeValue(athlete: entry.athlete).displayString,
                splitTimes: splitStrings
            )
        }
        let relayRows = relayLegData.enumerated().map { i, entry in
            let intermediates: [(label: String, time: String)]
            if race.splitsPerLap > 1 {
                intermediates = RaceDomain.relayLegIntermediateSplits(
                    legIndex: i,
                    athletes: orderedAthletes,
                    splits: splits,
                    race: race
                ).map { (label: $0.label, time: $0.lapMs.formattedSplitTime) }
            } else {
                intermediates = []
            }
            return CardData.CardRelayLeg(
                leg: entry.leg,
                athleteName: entry.athlete.firstName,
                colorHex: entry.athlete.colorHex,
                legTime: entry.legMs.map { $0.formattedSplitTime } ?? "—",
                cumulativeTime: entry.cumulativeMs.map { $0.formattedSplitTime } ?? "—",
                intermediateSplits: intermediates
            )
        }
        return CardData(
            raceName: race.name,
            eventDisplayName: race.eventType.displayName,
            startedAt: race.startedAt,
            meetName: meet?.name ?? race.spectatorMeetName,
            displayModeName: displayMode.rawValue,
            isRelay: race.eventType.isRelay,
            athletes: athleteRows,
            columnLabels: labels,
            relayLegs: relayRows,
            totalRelayTime: totalRelayMs.map { $0.formattedSplitTime },
            isMerged: race.isMerged,
            heat: race.heat,
            overallPlace: race.overallPlace,
            heatPlace: race.heatPlace,
            isOfficiallyTimed: race.isOfficiallyTimed,
            officialFinalTime: race.officialFinalMs.map { $0.formattedSplitTime }
        )
    }

    @MainActor
    func shareableImageURL() -> URL? {
        let data = buildCardData()
        let image = CardRenderer.render(data: data)
        guard let pngData = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RunsmithResults.png")
        try? pngData.write(to: url)
        return url
    }

    func csvFileURL() -> URL? {
        let csv = exportCSV()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(csvFilename())
        do {
            try csv.write(to: tmp, atomically: true, encoding: .utf8)
            return tmp
        } catch {
            return nil
        }
    }

    // MARK: – Merge Export

    /// Builds a CoachSplitPayload from this ViewModel's current athletes and splits.
    /// Used by ExportSplitsView to generate the assistant coach's shareable QR code.
    func buildCoachSplitPayload() -> CoachSplitPayload {
        let athleteTimingData: [AthleteTimingData] = orderedAthletes.map { athlete in
            let sortedSplits = splits
                .filter { $0.athleteId == athlete.id }
                .sorted { $0.lapIndex < $1.lapIndex }
                .map { $0.elapsedMs }
            return AthleteTimingData(
                athleteId: athlete.id,
                splits: sortedSplits
            )
        }
        return CoachSplitPayload(
            version: 1,
            configId: race.configId ?? UUID(),
            coachName: CoachIdentity.name ?? "Coach",
            exportedAt: Date(),
            athleteSplits: athleteTimingData,
            raceName: race.name,
            eventType: race.eventType.displayName,
            meetName: meet?.name
        )
    }
}
