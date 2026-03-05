import Foundation

enum RosterImporter {

    struct ImportRow {
        let name: String
        let gender: Gender
        let teamName: String?
    }

    enum RowResult {
        case new(Athlete)
        case duplicate(name: String)
        case error(line: Int, reason: String)
    }

    struct ImportResult {
        let rows: [RowResult]

        var newCount: Int {
            rows.filter {
                if case .new = $0 { return true }
                return false
            }.count
        }

        var dupCount: Int {
            rows.filter {
                if case .duplicate = $0 { return true }
                return false
            }.count
        }

        var errCount: Int {
            rows.filter {
                if case .error = $0 { return true }
                return false
            }.count
        }

        var newAthletes: [Athlete] {
            rows.compactMap {
                if case .new(let a) = $0 { return a }
                return nil
            }
        }
    }

    // MARK: — CSV Parsing

    static func parseCSV(_ text: String, existingAthletes: [Athlete]) -> ImportResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return ImportResult(rows: [.error(line: 1, reason: "File is empty or has no data rows")])
        }

        let header = parseCSVRow(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let firstNameIdx = header.firstIndex(of: "first name")
        let lastNameIdx = header.firstIndex(of: "last name")
        let genderIdx = header.firstIndex(of: "gender")
        let teamIdx = header.firstIndex(of: "team")

        guard let firstNameIdx, let lastNameIdx, let genderIdx else {
            return ImportResult(rows: [.error(line: 1, reason: "Missing required columns: First Name, Last Name, Gender")])
        }

        let colorPalette = RaceSetupViewModel.colorPalette
        var results: [RowResult] = []

        for (i, line) in lines.dropFirst().enumerated() {
            let cols = parseCSVRow(line)
            let lineNum = i + 2

            guard firstNameIdx < cols.count, lastNameIdx < cols.count, genderIdx < cols.count else {
                results.append(.error(line: lineNum, reason: "Not enough columns"))
                continue
            }

            let firstName = cols[firstNameIdx].trimmingCharacters(in: .whitespaces)
            let lastName = cols[lastNameIdx].trimmingCharacters(in: .whitespaces)
            let genderStr = cols[genderIdx].trimmingCharacters(in: .whitespaces).uppercased()
            let team = teamIdx.flatMap { idx -> String? in
                guard idx < cols.count else { return nil }
                let t = cols[idx].trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }

            let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")

            guard !name.isEmpty else {
                results.append(.error(line: lineNum, reason: "First Name and Last Name are both empty"))
                continue
            }

            guard let gender = Gender(rawValue: genderStr) else {
                results.append(.error(line: lineNum, reason: "Gender must be M or F, got '\(cols[genderIdx])'"))
                continue
            }

            let isDuplicate = existingAthletes.contains {
                $0.name.lowercased() == name.lowercased() && $0.gender == gender
            }

            if isDuplicate {
                results.append(.duplicate(name: name))
            } else {
                let athlete = Athlete(
                    name: name,
                    teamName: team,
                    colorHex: colorPalette[results.count % colorPalette.count],
                    gender: gender
                )
                results.append(.new(athlete))
            }
        }

        return ImportResult(rows: results)
    }

    // MARK: — CSV Row Parsing (handles quoted fields with commas inside)

    private static func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
