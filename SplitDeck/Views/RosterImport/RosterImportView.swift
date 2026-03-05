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
                allowedContentTypes: [.commaSeparatedText],
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
                Text("Your CSV file needs these columns (first row = headers):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("First Name").bold().frame(width: 80, alignment: .leading)
                        Text("Last Name").bold().frame(width: 80, alignment: .leading)
                        Text("Gender").bold().frame(width: 55, alignment: .leading)
                        Text("Team").bold().frame(width: 80, alignment: .leading)
                    }
                    .font(.caption.monospaced())

                    Divider()

                    ForEach([
                        ("Jake", "Miller", "M", "Westmoore"),
                        ("Sarah", "Chen", "F", "Edmond N"),
                        ("Tobi", "Akins", "M", "")
                    ], id: \.0) { row in
                        HStack(spacing: 0) {
                            Text(row.0).frame(width: 80, alignment: .leading)
                            Text(row.1).frame(width: 80, alignment: .leading)
                            Text(row.2).frame(width: 55, alignment: .leading)
                            Text(row.3.isEmpty ? "(blank)" : row.3)
                                .frame(width: 80, alignment: .leading)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.monospaced())
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Label("First Name, Last Name & Gender required", systemImage: "asterisk")
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
                Label("Choose CSV File", systemImage: "square.and.arrow.down")
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
                Rectangle()
                    .fill(Theme.genderColor(athlete.gender))
                    .frame(width: 4)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text(athlete.name).font(.subheadline)
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

                let csvText = try String(contentsOf: url, encoding: .utf8)

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
