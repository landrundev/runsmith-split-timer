import SwiftUI

enum SpectatorRoundType: String, CaseIterable {
    case none = "Heat"
    case semis = "Semis"
    case final_ = "Final"
}

struct SpectatorSetupView: View {
    enum SetupMode { case addAthlete, startRace }

    let mode: SetupMode

    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Environment(\.dismiss) private var dismiss

    // Add Athlete fields
    @State private var athleteName = ""
    @State private var displayNameOverride = ""
    @State private var gender: Gender = .male

    // Start Race fields
    @State private var raceTab: RaceTab = .individual
    @State private var selectedChildIndex = 0
    @State private var someoneElseName = ""
    @State private var usingSomeoneElse = false
    @State private var eventType: EventType = .m1600
    @State private var raceName = ""
    @State private var meetName = ""
    @State private var heatNumber = ""
    @State private var roundType: SpectatorRoundType = .none

    // Navigation
    @State private var savedRace: Race? = nil
    @State private var navigateToStaging = false
    @State private var showAddConfirm = false
    @State private var pendingAthleteForConfirm: Athlete? = nil

    enum RaceTab: String, CaseIterable {
        case individual = "Individual"
        case relay = "Relay"
    }

    private var myChildren: [AppSettings.SpectatorChild] {
        AppSettings.myChildren
    }

    private static let individualEvents: [EventType] = [
        .m100, .m200, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000
    ]

    /// Computed heat string from roundType + heatNumber
    private var computedHeat: String? {
        switch roundType {
        case .semis: return "Semis"
        case .final_: return "Final"
        case .none:
            if let num = Int(heatNumber), num > 0 { return "Heat \(num)" }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .addAthlete:
                    addAthleteForm
                case .startRace:
                    startRaceForm
                }
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle(mode == .addAthlete ? "Add Athlete" : "Time a Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToStaging) {
                if let race = savedRace {
                    SpectatorStagingView(race: race, store: store, cache: cache) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Add \(pendingAthleteForConfirm?.name ?? "") to your athletes?",
                                isPresented: $showAddConfirm,
                                titleVisibility: .visible) {
                Button("Add") {
                    if let athlete = pendingAthleteForConfirm {
                        let displayName = String(athlete.name.split(separator: " ").first ?? Substring(athlete.name))
                        AppSettings.addChild(AppSettings.SpectatorChild(
                            id: athlete.id,
                            displayName: displayName,
                            addedAt: Date()
                        ))
                    }
                    finalizeRace()
                }
                Button("Not now") {
                    finalizeRace()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Add Athlete Form

    private var addAthleteForm: some View {
        Form {
            Section {
                TextField("Athlete name", text: $athleteName)
                TextField("Display name (optional)", text: $displayNameOverride)
            } header: {
                Text("Athlete Info")
            }

            Section {
                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Save Athlete") {
                    saveAthlete()
                }
                .disabled(athleteName.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Theme.runsmithPink)
                .font(.headline)
            }
        }
    }

    // MARK: - Start Race Form

    private var startRaceForm: some View {
        VStack(spacing: 0) {
            Picker("Race Type", selection: $raceTab) {
                ForEach(RaceTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            switch raceTab {
            case .individual:
                individualSetupForm
            case .relay:
                SpectatorRelaySetupView(
                    onSaveAndDismiss: { dismiss() },
                    onReadyToTime: { race in
                        savedRace = race
                        navigateToStaging = true
                    }
                )
            }
        }
    }

    private var individualSetupForm: some View {
        Form {
            // WHO ARE YOU TIMING?
            Section {
                if myChildren.count == 1 {
                    HStack {
                        Text("Athlete")
                        Spacer()
                        Text(myChildren[0].displayName)
                            .foregroundStyle(.secondary)
                    }
                } else if myChildren.count > 1 {
                    Picker("Athlete", selection: $selectedChildIndex) {
                        ForEach(Array(myChildren.enumerated()), id: \.offset) { i, child in
                            Text(child.displayName).tag(i)
                        }
                    }
                }

                if !usingSomeoneElse {
                    Button("+ Time someone else") {
                        usingSomeoneElse = true
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.runsmithPink)
                } else {
                    TextField("Name", text: $someoneElseName)
                }
            } header: {
                Text("Who are you timing?")
            }

            // MEET & EVENT
            Section {
                TextField("e.g. City Championships", text: $meetName)
                Picker("Event", selection: $eventType) {
                    ForEach(Self.individualEvents, id: \.self) { event in
                        Text(event.displayName).tag(event)
                    }
                }
            } header: {
                Text("Meet & Event")
            }

            // ROUND
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

            // RACE NAME
            Section {
                TextField("Race name", text: $raceName)
                    .onAppear { updateAutoName() }
                    .onChange(of: eventType) { _ in updateAutoName() }
                    .onChange(of: selectedChildIndex) { _ in updateAutoName() }
            } header: {
                Text("Race Name")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    saveIndividualRace(andStage: false)
                } label: {
                    Text("Save & Close")
                        .frame(width: 140)
                }
                .buttonStyle(GlassSecondaryButtonStyle())

                Button {
                    saveIndividualRace(andStage: true)
                } label: {
                    Text("Ready to Time \u{203A}")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPrimaryButtonStyle(color: Theme.runsmithPink))
            }
            .glassActionBar()
        }
    }

    // MARK: - Actions

    private func saveAthlete() {
        let name = athleteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard let athlete = try? store.findOrCreateSpectatorAthlete(name: name, gender: gender) else { return }
        let display = displayNameOverride.trimmingCharacters(in: .whitespaces)
        let displayName = display.isEmpty ? String(name.split(separator: " ").first ?? Substring(name)) : display
        AppSettings.addChild(AppSettings.SpectatorChild(id: athlete.id, displayName: displayName, addedAt: Date()))
        dismiss()
    }

    private func saveIndividualRace(andStage: Bool) {
        let athlete: Athlete
        if usingSomeoneElse && !someoneElseName.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let a = try? store.findOrCreateSpectatorAthlete(
                name: someoneElseName.trimmingCharacters(in: .whitespaces),
                gender: gender
            ) else { return }
            athlete = a
            // Check if we should offer to add to myChildren
            if !myChildren.contains(where: { $0.id == a.id }) {
                pendingAthleteForConfirm = a
                // Store race info for later finalization
                buildAndSaveRace(athleteId: a.id, andStage: andStage)
                showAddConfirm = true
                return
            }
        } else {
            guard !myChildren.isEmpty else { return }
            let child = myChildren[min(selectedChildIndex, myChildren.count - 1)]
            guard let allAthletes = try? store.fetchAthletes(),
                  let a = allAthletes.first(where: { $0.id == child.id })
            else { return }
            athlete = a
        }

        buildAndSaveRace(athleteId: athlete.id, andStage: andStage)
        if andStage {
            navigateToStaging = true
        } else {
            dismiss()
        }
    }

    private func buildAndSaveRace(athleteId: UUID, andStage: Bool) {
        let name = raceName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(eventType.displayName)"
            : raceName.trimmingCharacters(in: .whitespaces)
        let meetTrimmed = meetName.trimmingCharacters(in: .whitespaces)
        let race = Race(
            name: name,
            eventType: eventType,
            distanceMeters: eventType.defaultDistance ?? 0,
            trackLengthMeters: 400,
            splitsPerLap: 1,
            athleteIds: [athleteId],
            status: .notStarted,
            spectatorMeetName: meetTrimmed.isEmpty ? nil : meetTrimmed,
            heat: computedHeat
        )

        // Only persist to Core Data when explicitly saving, not when staging
        if !andStage {
            try? store.save(race)
        }
        savedRace = race

        // Save as quick-start template
        let displayName: String
        if usingSomeoneElse {
            displayName = someoneElseName.trimmingCharacters(in: .whitespaces)
        } else if !myChildren.isEmpty {
            displayName = myChildren[min(selectedChildIndex, myChildren.count - 1)].displayName
        } else {
            displayName = ""
        }
        let templateLabel = displayName.isEmpty ? eventType.displayName : "\(displayName) \u{00B7} \(eventType.displayName)"
        AppSettings.saveQuickRaceTemplate(label: templateLabel, athleteId: athleteId, eventTypeRaw: eventType.rawValue)
    }

    private func finalizeRace() {
        if savedRace != nil {
            navigateToStaging = true
        } else {
            dismiss()
        }
    }

    private func updateAutoName() {
        let displayName: String
        if usingSomeoneElse {
            displayName = someoneElseName.trimmingCharacters(in: .whitespaces)
        } else if !myChildren.isEmpty {
            displayName = myChildren[min(selectedChildIndex, myChildren.count - 1)].displayName
        } else {
            displayName = ""
        }
        raceName = "\(displayName) \(eventType.displayName)".trimmingCharacters(in: .whitespaces)
    }
}
