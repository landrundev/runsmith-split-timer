import SwiftUI

struct SpectatorRelaySetupView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    let onSaveAndDismiss: () -> Void
    let onReadyToTime: (Race) -> Void

    @State private var eventType: EventType = .relay4x400
    @State private var gender: Gender = .male
    @State private var legNames: [String] = ["", "", "", ""]
    @State private var teamName = ""
    @State private var savedTeams: [SavedRelayTeam] = []
    @State private var loadedTeamId: UUID? = nil

    private static let relayEvents: [EventType] = [
        .relay4x100, .relay4x200, .relay4x400, .relay4x800
    ]

    private var myChildren: [AppSettings.SpectatorChild] {
        AppSettings.myChildren
    }

    var body: some View {
        Form {
            // EVENT
            Section {
                Picker("Event", selection: $eventType) {
                    ForEach(Self.relayEvents, id: \.self) { event in
                        Text(event.displayName).tag(event)
                    }
                }
                .onChange(of: eventType) { _ in loadTeams() }
            } header: {
                Text("Event")
            }

            // GENDER
            Section {
                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
                .onChange(of: gender) { _ in loadTeams() }
            }

            // SAVED TEAMS
            if !matchingTeams.isEmpty {
                Section {
                    ForEach(matchingTeams) { team in
                        Button {
                            loadTeam(team)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(team.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        ForEach(resolvedNames(for: team), id: \.self) { name in
                                            Text(name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                if loadedTeamId == team.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.runsmithPink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let teamsToDelete = offsets.map { matchingTeams[$0] }
                        for team in teamsToDelete {
                            try? store.delete(relayTeamId: team.id)
                        }
                        loadTeams()
                    }
                } header: {
                    Text("Saved Teams")
                }
            }

            // LEG ORDER
            Section {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("LEG \(i + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        TextField("Athlete name", text: $legNames[i])
                    }
                }
            } header: {
                Text("Leg Order")
            }

            // TEAM NAME
            Section {
                TextField("e.g. Varsity Boys 4\u{00D7}400", text: $teamName)
            } header: {
                Text("Team Name")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    saveTeamOnly()
                } label: {
                    Label("Save Team", systemImage: "square.and.arrow.down")
                        .frame(width: 140)
                }
                .buttonStyle(GlassSecondaryButtonStyle())

                Button {
                    saveTeamAndRace()
                } label: {
                    Text("Ready to Time \u{203A}")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPrimaryButtonStyle(color: Theme.runsmithPink))
            }
            .glassActionBar()
        }
        .onAppear { loadTeams() }
    }

    // MARK: - Helpers

    private var matchingTeams: [SavedRelayTeam] {
        savedTeams.filter { $0.eventType == eventType && $0.gender == gender }
    }

    private func resolvedNames(for team: SavedRelayTeam) -> [String] {
        let allAthletes = (try? store.fetchAthletes()) ?? []
        return team.athleteIds.compactMap { id in
            allAthletes.first { $0.id == id }?.firstName
        }
    }

    private func loadTeam(_ team: SavedRelayTeam) {
        loadedTeamId = team.id
        teamName = team.name
        let allAthletes = (try? store.fetchAthletes()) ?? []
        legNames = team.athleteIds.map { id in
            allAthletes.first { $0.id == id }?.name ?? ""
        }
        // Pad to 4 if needed
        while legNames.count < 4 { legNames.append("") }
    }

    private func loadTeams() {
        savedTeams = (try? store.fetchSavedRelayTeams()) ?? []
    }

    private func resolveAthletes() -> [UUID] {
        legNames.compactMap { name -> UUID? in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            guard let athlete = try? store.findOrCreateSpectatorAthlete(name: trimmed, gender: gender)
            else { return nil }
            return athlete.id
        }
    }

    private func autoTeamName() -> String {
        let genderName = gender == .male ? "Male" : "Female"
        return "\(genderName) \(eventType.displayName)"
    }

    private func saveTeamOnly() {
        let athleteIds = resolveAthletes()
        guard athleteIds.count == 4 else { return }
        let name = teamName.trimmingCharacters(in: .whitespaces).isEmpty ? autoTeamName() : teamName
        let team = SavedRelayTeam(name: name, eventType: eventType, gender: gender, athleteIds: athleteIds)
        try? store.save(team)
        onSaveAndDismiss()
    }

    private func saveTeamAndRace() {
        let athleteIds = resolveAthletes()
        guard athleteIds.count == 4 else { return }
        let name = teamName.trimmingCharacters(in: .whitespaces).isEmpty ? autoTeamName() : teamName
        let team = SavedRelayTeam(name: name, eventType: eventType, gender: gender, athleteIds: athleteIds)
        try? store.save(team)

        let race = Race(
            name: name,
            eventType: eventType,
            distanceMeters: eventType.legDistanceMeters.map { $0 * 4 } ?? 1600,
            trackLengthMeters: eventType.legDistanceMeters ?? 400,
            splitsPerLap: 1,
            athleteIds: athleteIds,
            status: .notStarted
        )
        // Race is NOT saved to Core Data here — it will be persisted
        // when the user actually starts timing in SpectatorStagingView.

        // Save as quick-start template
        AppSettings.saveQuickRaceTemplate(
            label: name,
            athleteId: athleteIds[0],
            eventTypeRaw: eventType.rawValue,
            isRelay: true,
            relayAthleteIds: athleteIds
        )

        onReadyToTime(race)
    }
}
