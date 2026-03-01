import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable {
    case cumulative = "Cumulative"
    case lapTimes   = "Lap Times"
}

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var displayMode: DisplayMode = .cumulative

    let race: Race
    let athletes: [Athlete]
    let splits: [Split]
    let meet: Meet?

    init(race: Race, athletes: [Athlete], splits: [Split], meet: Meet?) {
        self.race = race
        self.athletes = athletes
        self.splits = splits
        self.meet = meet
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
        RaceDomain.cumulativeColumnLabels(for: race)
    }

    func cellValue(athlete: Athlete, lapIndex: Int) -> CellValue {
        switch displayMode {
        case .cumulative:
            return RaceDomain.cumulativeDisplay(
                athlete: athlete, lapIndex: lapIndex, splits: splits, race: race)
        case .lapTimes:
            return RaceDomain.lapTimeDisplay(
                athlete: athlete, lapIndex: lapIndex, splits: splits, race: race)
        }
    }

    /// Always returns the cumulative total time regardless of display mode — used for the header row.
    func totalTimeValue(athlete: Athlete) -> CellValue {
        RaceDomain.cumulativeDisplay(athlete: athlete, lapIndex: race.laps, splits: splits, race: race)
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
                cellValue(athlete: entry.athlete, lapIndex: i + 1).displayString
            }
            return CardData.CardAthlete(
                name: entry.athlete.name,
                colorHex: entry.athlete.colorHex,
                place: entry.place,
                totalTime: totalTimeValue(athlete: entry.athlete).displayString,
                splitTimes: splitStrings
            )
        }
        let relayRows = relayLegData.map { entry in
            CardData.CardRelayLeg(
                leg: entry.leg,
                athleteName: entry.athlete.name,
                colorHex: entry.athlete.colorHex,
                legTime: entry.legMs.map { $0.formattedSplitTime } ?? "—",
                cumulativeTime: entry.cumulativeMs.map { $0.formattedSplitTime } ?? "—"
            )
        }
        return CardData(
            raceName: race.name,
            eventDisplayName: race.eventType.displayName,
            startedAt: race.startedAt,
            meetName: meet?.name,
            displayModeName: displayMode.rawValue,
            isRelay: race.eventType.isRelay,
            athletes: athleteRows,
            columnLabels: labels,
            relayLegs: relayRows,
            totalRelayTime: totalRelayMs.map { $0.formattedSplitTime }
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
}
