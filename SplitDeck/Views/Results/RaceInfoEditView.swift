import SwiftUI

struct RaceInfoEditView: View {
    let race: Race
    let store: SplitDeckStore
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var raceName: String = ""
    @State private var raceDate: Date = Date()
    @State private var eventType: EventType = .m1600
    @State private var errorMessage: String? = nil

    private static let allEvents: [EventType] = [
        .m100, .m200, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000,
        .relay4x100, .relay4x200, .relay4x400, .relay4x800, .custom
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Race name", text: $raceName)
                } header: {
                    Text("Race Name")
                }

                Section {
                    DatePicker("Date", selection: $raceDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                } header: {
                    Text("Date")
                }

                Section {
                    Picker("Event", selection: $eventType) {
                        ForEach(Self.allEvents, id: \.self) { event in
                            Text(event.displayName).tag(event)
                        }
                    }
                } header: {
                    Text("Event")
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Race Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { loadValues() }
        }
    }

    private func loadValues() {
        raceName = race.name
        raceDate = race.startedAt ?? race.endedAt ?? Date()
        eventType = race.eventType
    }

    private func save() {
        let trimmed = raceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Race name cannot be empty."
            return
        }

        var updated = race
        updated.name = trimmed
        updated.startedAt = raceDate
        updated.eventType = eventType
        // Update distance if event type changed
        if eventType != race.eventType, let dist = eventType.defaultDistance {
            updated.distanceMeters = dist
        }

        do {
            try store.save(updated)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
