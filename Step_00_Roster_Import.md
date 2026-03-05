# Step 00 — Add CSV Roster Import to the Athlete Roster Screen

---

## CREATE `SplitDeck/Domain/RosterImporter.swift`

```swift
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
        let nameIdx = header.firstIndex(of: "name")
        let genderIdx = header.firstIndex(of: "gender")
        let teamIdx = header.firstIndex(of: "team")

        guard let nameIdx, let genderIdx else {
            return ImportResult(rows: [.error(line: 1, reason: "Missing required columns: Name, Gender")])
        }

        let colorPalette = RaceSetupViewModel.colorPalette
        var results: [RowResult] = []

        for (i, line) in lines.dropFirst().enumerated() {
            let cols = parseCSVRow(line)
            let lineNum = i + 2

            guard nameIdx < cols.count, genderIdx < cols.count else {
                results.append(.error(line: lineNum, reason: "Not enough columns"))
                continue
            }

            let name = cols[nameIdx].trimmingCharacters(in: .whitespaces)
            let genderStr = cols[genderIdx].trimmingCharacters(in: .whitespaces).uppercased()
            let team = teamIdx.flatMap { idx -> String? in
                guard idx < cols.count else { return nil }
                let t = cols[idx].trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }

            guard !name.isEmpty else {
                results.append(.error(line: lineNum, reason: "Name is empty"))
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
```

---

## CREATE `SplitDeck/Views/RosterImport/RosterImportView.swift`

```swift
import SwiftUI
import UniformTypeIdentifiers

struct RosterImportView: View {
    let store: SplitDeckStore
    @Environment(\.dismiss) private var dismiss

    @State private var importResult: RosterImporter.ImportResult?
    @State private var showFilePicker = false
    @State private var importComplete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                formatGuideSection

                chooseFileSection

                if let result = importResult {
                    previewSection(result)
                    importButtonSection(result)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import Athletes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .spreadsheet],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Complete", isPresented: $importComplete) {
                Button("Done") { dismiss() }
            } message: {
                if let r = importResult {
                    Text("Added \(r.newCount) athlete\(r.newCount == 1 ? "" : "s") to your roster.")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: — Sections

    private var formatGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your CSV or Excel file needs these columns (first row = headers):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Name").bold().frame(width: 110, alignment: .leading)
                        Text("Gender").bold().frame(width: 70, alignment: .leading)
                        Text("Team").bold().frame(width: 100, alignment: .leading)
                    }
                    .font(.caption.monospaced())

                    Divider()

                    ForEach([
                        ("Jake Miller", "M", "Westmoore"),
                        ("Sarah Chen", "F", "Edmond North"),
                        ("Tobi Akins", "M", "")
                    ], id: \.0) { row in
                        HStack(spacing: 0) {
                            Text(row.0).frame(width: 110, alignment: .leading)
                            Text(row.1).frame(width: 70, alignment: .leading)
                            Text(row.2.isEmpty ? "(blank)" : row.2)
                                .frame(width: 100, alignment: .leading)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.monospaced())
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Name & Gender required", systemImage: "asterisk")
                    Label("Gender: M or F", systemImage: "person")
                    Label("Team is optional", systemImage: "building.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("File Format", systemImage: "doc.text")
        }
    }

    private var chooseFileSection: some View {
        Section {
            Button {
                showFilePicker = true
            } label: {
                Label("Choose File (.csv / .xlsx)", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.runsmithPink)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    @ViewBuilder
    private func previewSection(_ result: RosterImporter.ImportResult) -> some View {
        Section {
            ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        } header: {
            Text("Preview")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.rows.count) athlete\(result.rows.count == 1 ? "" : "s") found")
                Text("\(result.newCount) new \u{00B7} \(result.dupCount) duplicate \u{00B7} \(result.errCount) error")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: RosterImporter.RowResult) -> some View {
        switch row {
        case .new(let athlete):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(athlete.name).font(.subheadline)
                        if let gender = athlete.gender {
                            Text(gender.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.genderTint(gender))
                                .clipShape(Capsule())
                        }
                    }
                    if let team = athlete.teamName {
                        Text(team).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

        case .duplicate(let name):
            HStack(spacing: 12) {
                Image(systemName: "slash.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline).foregroundStyle(.secondary)
                    Text("Duplicate \u{2014} will skip").font(.caption).foregroundStyle(.secondary)
                }
            }

        case .error(let line, let reason):
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Row \(line)").font(.subheadline).foregroundStyle(.orange)
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func importButtonSection(_ result: RosterImporter.ImportResult) -> some View {
        Section {
            Button {
                importAthletes(result.newAthletes)
            } label: {
                Text("Import \(result.newCount) Athlete\(result.newCount == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.runsmithPink)
            .disabled(result.newCount == 0)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

            Text("Duplicates matched by name + gender are skipped.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }

    // MARK: — Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "Could not open file: \(error.localizedDescription)"

        case .success(let urls):
            guard let url = urls.first else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let existingAthletes = (try? store.fetchAthletes()) ?? []

                let csvText: String
                if url.pathExtension.lowercased() == "csv" {
                    csvText = try String(contentsOf: url, encoding: .utf8)
                } else {
                    // For .xlsx or other formats: attempt UTF-8 then ISO-8859-1 fallback
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        csvText = text
                    } else {
                        csvText = try String(contentsOf: url, encoding: .isoLatin1)
                    }
                }

                importResult = RosterImporter.parseCSV(csvText, existingAthletes: existingAthletes)
            } catch {
                errorMessage = "Could not read file: \(error.localizedDescription)"
            }
        }
    }

    private func importAthletes(_ athletes: [Athlete]) {
        for athlete in athletes {
            try? store.save(athlete)
        }
        importComplete = true
    }
}
```

---

## MODIFY `SplitDeck/Views/AthleteProfile/AthleteRosterView.swift`

### Change 1: Add `showRosterImport` state property

**Find** (immediately after `@State private var athleteToDelete: Athlete? = nil`):
```swift
    // Delete athlete
    @State private var athleteToDelete: Athlete? = nil
```

**Replace with**:
```swift
    // Delete athlete
    @State private var athleteToDelete: Athlete? = nil

    // Import from file
    @State private var showRosterImport = false
```

---

### Change 2: Replace toolbar `Button` with a `Menu`

**Find**:
```swift
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newName = ""
                    newTeam = ""
                    newGender = nil
                    newColorHex = RaceSetupViewModel.colorPalette[athletes.count % RaceSetupViewModel.colorPalette.count]
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
```

**Replace with**:
```swift
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        newName = ""
                        newTeam = ""
                        newGender = nil
                        newColorHex = RaceSetupViewModel.colorPalette[athletes.count % RaceSetupViewModel.colorPalette.count]
                        showAddSheet = true
                    } label: {
                        Label("Add Athlete", systemImage: "plus")
                    }

                    Button {
                        showRosterImport = true
                    } label: {
                        Label("Import from File", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
```

---

### Change 3: Add `RosterImportView` sheet and `onChange` refresh

**Find**:
```swift
        .onAppear { refreshAthletes() }
```

**Replace with**:
```swift
        .sheet(isPresented: $showRosterImport) {
            RosterImportView(store: store)
        }
        .onChange(of: showRosterImport) { showing in
            if !showing { refreshAthletes() }
        }
        .onAppear { refreshAthletes() }
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] On the Athletes screen, tapping `+` shows a menu with "Add Athlete" and "Import from File"
- [ ] Tapping "Add Athlete" opens the existing add-athlete sheet (unchanged behavior)
- [ ] Tapping "Import from File" opens the `RosterImportView` sheet
- [ ] The import sheet displays the File Format guide with the monospaced example table
- [ ] Tapping "Choose File" opens the system file picker filtered to `.csv` and spreadsheet types
- [ ] Selecting a valid CSV file shows a preview list with green checks (new), gray slashes (duplicate), orange warnings (errors)
- [ ] The summary footer shows "X new · Y duplicate · Z error" counts
- [ ] The "Import X Athletes" button is disabled when `newCount == 0`
- [ ] Tapping "Import X Athletes" saves the new athletes and dismisses with a confirmation alert
- [ ] After the sheet closes, the Athletes list refreshes and shows all newly imported athletes
- [ ] Re-importing the same CSV file shows every row as a duplicate (all gray slashes, button disabled)
- [ ] An empty CSV (header only, no data rows) shows a single error row explaining the file is empty
- [ ] A CSV missing the Name or Gender column shows a single error row with the column names listed
