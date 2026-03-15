import SwiftUI

struct OfficialTimeEntryView: View {
    let race: Race
    let manualFinalMs: Int
    let store: SplitDeckStore
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var centiseconds: Int = 0
    @State private var adjustSplits: Bool = true
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private var officialMs: Int {
        (minutes * 60_000) + (seconds * 1_000) + (centiseconds * 10)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // YOUR RECORDED TIME
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR RECORDED TIME")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Manual time")
                                .font(.subheadline)
                            Spacer()
                            Text(manualFinalMs.formattedSplitTime)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    }

                    // OFFICIAL TIME
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OFFICIAL TIME")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 2) {
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                            .clipped()

                            Text(":")
                                .font(.title2.weight(.semibold))

                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60, id: \.self) { s in
                                    Text(String(format: "%02d", s)).tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                            .clipped()

                            Text(".")
                                .font(.title2.weight(.semibold))

                            Picker("Centiseconds", selection: $centiseconds) {
                                ForEach(0..<100, id: \.self) { cs in
                                    Text(String(format: "%02d", cs)).tag(cs)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                            .clipped()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

                        // Difference row
                        if officialMs > 0 && officialMs != manualFinalMs {
                            let diffMs = officialMs - manualFinalMs
                            let sign = diffMs < 0 ? "\u{2212}" : "+"
                            HStack {
                                Spacer()
                                Text("\(sign)\(abs(diffMs).formattedSplitTime) vs manual")
                                    .font(.caption)
                                    .foregroundStyle(diffMs < 0 ? .green : .orange)
                                Spacer()
                            }
                        }
                    }

                    // ADJUST SPLITS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADJUST SPLITS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Adjust splits proportionally", isOn: $adjustSplits)
                                .font(.subheadline)

                            if adjustSplits {
                                Text("Each recorded split will be scaled so the final time matches the official result. Your pacing pattern is preserved.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Only the official finish time is recorded. Your manually timed splits remain unchanged.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Official Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .onAppear { parseManualTime() }
        }
    }

    private func parseManualTime() {
        let totalMs = manualFinalMs
        minutes = totalMs / 60_000
        let remainder = totalMs % 60_000
        seconds = remainder / 1_000
        centiseconds = (remainder % 1_000) / 10
    }

    private func save() {
        guard officialMs > 0 else {
            errorMessage = "Please enter a valid time."
            return
        }
        isSaving = true
        do {
            try store.recordOfficialTime(
                raceId: race.id,
                officialMs: officialMs,
                adjustSplits: adjustSplits
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
