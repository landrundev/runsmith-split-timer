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
    @State private var heatNumber: String = ""
    @State private var roundType: SpectatorRoundType = .none
    @State private var overallPlace: String = ""
    @State private var heatPlace: String = ""
    @State private var errorMessage: String? = nil

    private static let allEvents: [EventType] = [
        .m100, .m110H, .m200, .m300H, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000,
        .relay4x100, .relay4x200, .relay4x400, .relay4x800, .custom
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Race Name
                Section {
                    TextField("e.g. Boys 1600m", text: $raceName)
                        .font(.body)
                } header: {
                    Text("Race Name")
                }

                // Meet & Event
                Section {
                    TextField("e.g. City Championships", text: $meetName)
                    Picker("Event", selection: $eventType) {
                        ForEach(Self.allEvents, id: \.self) { event in
                            Text(event.displayName).tag(event)
                        }
                    }
                } header: {
                    Text("Meet & Event")
                }

                // Date
                Section {
                    DatePicker("Date", selection: $raceDate, displayedComponents: .date)
                } header: {
                    Text("Date")
                }

                // Round
                Section {
                    Picker("Round", selection: $roundType) {
                        ForEach(SpectatorRoundType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if roundType == .none {
                        HStack {
                            Text("Heat Number")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            TextField("—", text: $heatNumber)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                } header: {
                    Text("Round")
                }

                // Placement
                Section {
                    HStack {
                        Text("Overall Place")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("—", text: $overallPlace)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Heat Place")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("—", text: $heatPlace)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                } header: {
                    Text("Placement")
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
        overallPlace = race.overallPlace.map { "\($0)" } ?? ""
        heatPlace = race.heatPlace.map { "\($0)" } ?? ""

        // Parse existing heat string into roundType + heatNumber
        if let heat = race.heat {
            if heat == "Semis" {
                roundType = .semis
            } else if heat == "Final" {
                roundType = .final_
            } else if heat.hasPrefix("Heat "), let num = Int(heat.dropFirst(5)) {
                roundType = .none
                heatNumber = "\(num)"
            } else {
                roundType = .none
                heatNumber = ""
            }
        } else {
            roundType = .none
            heatNumber = ""
        }
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

        // Build heat string from roundType + heatNumber
        switch roundType {
        case .semis:
            updated.heat = "Semis"
        case .final_:
            updated.heat = "Final"
        case .none:
            if let num = Int(heatNumber), num > 0 {
                updated.heat = "Heat \(num)"
            } else {
                updated.heat = nil
            }
        }

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
