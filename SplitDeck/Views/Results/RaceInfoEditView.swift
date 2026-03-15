import SwiftUI

struct RaceInfoEditView: View {
    let race: Race
    let store: SplitDeckStore
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var raceName: String = ""
    @State private var raceDate: Date = Date()
    @State private var eventType: EventType = .m1600
    @State private var meetName: String = ""
    @State private var selectedHeat: String = "None"
    @State private var overallPlace: String = ""
    @State private var heatPlace: String = ""
    @State private var errorMessage: String? = nil

    private static let allEvents: [EventType] = [
        .m100, .m200, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000,
        .relay4x100, .relay4x200, .relay4x400, .relay4x800, .custom
    ]

    private static let heatOptions: [String] = {
        var opts = ["None"]
        opts += (1...20).map { "Heat \($0)" }
        opts += ["Semis", "Final"]
        return opts
    }()

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

                Section {
                    TextField("e.g. City Championships", text: $meetName)
                } header: {
                    Text("Meet")
                }

                Section {
                    Picker("Heat", selection: $selectedHeat) {
                        ForEach(Self.heatOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } header: {
                    Text("Heat")
                }

                Section {
                    HStack {
                        Text("Overall")
                        Spacer()
                        TextField("—", text: $overallPlace)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Heat")
                        Spacer()
                        TextField("—", text: $heatPlace)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                } header: {
                    Text("Place")
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
        meetName = race.spectatorMeetName ?? ""
        selectedHeat = race.heat ?? "None"
        overallPlace = race.overallPlace.map { "\($0)" } ?? ""
        heatPlace = race.heatPlace.map { "\($0)" } ?? ""
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
        if eventType != race.eventType, let dist = eventType.defaultDistance {
            updated.distanceMeters = dist
        }

        let meetTrimmed = meetName.trimmingCharacters(in: .whitespaces)
        updated.spectatorMeetName = meetTrimmed.isEmpty ? nil : meetTrimmed
        updated.heat = selectedHeat == "None" ? nil : selectedHeat
        updated.overallPlace = Int(overallPlace)
        updated.heatPlace = Int(heatPlace)

        do {
            try store.save(updated)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
