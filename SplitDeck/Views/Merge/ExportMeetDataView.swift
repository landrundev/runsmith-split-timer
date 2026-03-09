import SwiftUI

/// Assistant coach flow: export all split data for a meet as a single `.runsmith` file.
struct ExportMeetDataView: View {
    let payload: CoachMeetPayload
    let meetName: String

    @Environment(\.dismiss) private var dismiss
    @State private var copyConfirmed = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: — Summary
                Section {
                    row(icon: "person.circle", label: "Coach", value: payload.coachName)
                    row(icon: "calendar", label: "Meet", value: meetName)
                    row(icon: "flag.checkered", label: "Races", value: "\(payload.racePayloads.count)")
                    let uniqueAthletes = Set(payload.racePayloads.flatMap { $0.athleteSplits.map(\.athleteId) }).count
                    row(icon: "person.3", label: "Athletes Timed", value: "\(uniqueAthletes)")
                } header: {
                    Text("Export Summary")
                } footer: {
                    Text("This file contains your split data for every completed race in this meet.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                // MARK: — Included Races
                if !payload.racePayloads.isEmpty {
                    Section {
                        ForEach(payload.racePayloads) { entry in
                            HStack {
                                Text(entry.raceName)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(entry.athleteSplits.count) athlete\(entry.athleteSplits.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    } header: {
                        Text("Included Races")
                    }
                }

                // MARK: — How It Works
                Section {
                    Label("Share this file with your head coach", systemImage: "1.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Label("They tap the file \u{2014} Runsmith opens automatically", systemImage: "2.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Label("All races merge at once \u{2014} no repeating per race", systemImage: "3.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                } header: {
                    Text("How It Works")
                }

                // MARK: — Actions
                Section {
                    if let fileURL = PayloadEncoder.writeRunsmithFile(payload, meetName: meetName) {
                        ShareLink(
                            item: fileURL,
                            preview: SharePreview(
                                "\(meetName) Timing Data",
                                icon: Image(systemName: "stopwatch.fill")
                            )
                        ) {
                            Label("Share File", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }

                    if let qrString = PayloadEncoder.encodeForQR(payload) {
                        Button {
                            UIPasteboard.general.string = qrString
                            copyConfirmed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copyConfirmed = false
                            }
                        } label: {
                            Label(
                                copyConfirmed ? "Copied!" : "Copy QR String",
                                systemImage: copyConfirmed ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(copyConfirmed ? .green : .accentColor)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export Timing Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
