import Foundation

enum CSVExporter {

    // MARK: – Public API

    static func export(
        race: Race,
        rankedAthletes: [(athlete: Athlete, place: Int?)],
        splits: [Split],
        meet: Meet?
    ) -> String {
        let labels = RaceDomain.cumulativeColumnLabels(for: race, splits: splits)
        var rows: [String] = []

        // Header
        let header = (["Place", "Athlete"] + labels + ["Final"]).joined(separator: ",")
        rows.append(header)

        // Athlete rows
        for entry in rankedAthletes {
            let place = entry.place.map { String($0) } ?? "\u{2014}"
            let lapCells = labels.enumerated().map { (i, _) -> String in
                RaceDomain.cumulativeDisplayByOrdinal(
                    athlete: entry.athlete,
                    splitOrdinal: i + 1,
                    splits: splits,
                    race: race
                ).displayString
            }
            let final_ = lapCells.last ?? "\u{2014}"
            let row = ([place, csvEscape(entry.athlete.name)] + lapCells + [final_])
                .joined(separator: ",")
            rows.append(row)
        }

        return rows.joined(separator: "\n")
    }

    // MARK: – Filename

    static func filename(race: Race, meet: Meet?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        let dateStr: String
        if let meet = meet {
            dateStr = formatter.string(from: meet.date)
        } else if let startedAt = race.startedAt {
            dateStr = formatter.string(from: startedAt)
        } else {
            dateStr = formatter.string(from: Date())
        }

        let context = meet.map { slug(from: $0.name) } ?? "Quick-Race"
        let event = slug(from: race.name)
        let shortId = String(race.id.uuidString.prefix(8)).lowercased()

        return "\(dateStr)_\(context)_\(event)_race-\(shortId).csv"
    }

    // MARK: – Helpers

    private static func slug(from string: String) -> String {
        string
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .components(separatedBy: .init(charactersIn: "/\\:*?\"<>|.,;'"))
            .joined()
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
