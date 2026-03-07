import SwiftUI

private enum RelaySource: String, CaseIterable {
    case savedTeams = "Saved Teams"
    case athletes = "Athletes"
}

struct RaceSetupView: View {
    @ObservedObject var vm: RaceSetupViewModel
    let store: SplitDeckStore
    let cache: RaceStateCache

    @Environment(\.dismiss) private var dismiss
    @State private var showAddAthlete = false
    @State private var navigateToLiveTiming = false
    @State private var createdRace: Race?
    @State private var liveTimingVM: LiveTimingViewModel?

    // Athlete editing
    @State private var athleteToEdit: Athlete? = nil
    @State private var editName = ""
    @State private var editTeam = ""
    @State private var editColorHex = ""
    @State private var editGender: Gender? = nil

    // Athlete profile navigation (state-based, replaces inline NavigationLink)
    @State private var profileAthlete: Athlete? = nil

    // Relay source filter
    @State private var relaySource: RelaySource = .athletes

    // Relay builder navigation
    @State private var navigateToRelayBuilder = false

    // Multi-Coach sharing
    @State private var showShareConfig = false

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                athleteSection

                Button {
                    vm.ensureConfigId()
                    showShareConfig = true
                } label: {
                    Label("Share with Coaches", systemImage: "person.2.wave.2")
                }
                .disabled(!vm.isValid)
            }
            .navigationTitle(vm.existingRaceId != nil ? "Edit Race" : "Race Setup")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .sheet(isPresented: $showShareConfig) {
                ShareRaceConfigView(config: vm.buildSharedConfig())
            }
            .sheet(isPresented: $showAddAthlete) {
                addAthleteSheet
            }
            .sheet(item: $athleteToEdit) { athlete in
                editAthleteSheet(athlete: athlete)
            }
            .navigationDestination(isPresented: $navigateToLiveTiming) {
                if let liveVM = liveTimingVM {
                    LiveTimingView(vm: liveVM, cache: cache, onRaceComplete: { dismiss() })
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { profileAthlete != nil },
                set: { if !$0 { profileAthlete = nil } }
            )) {
                if let athlete = profileAthlete {
                    AthleteProfileView(
                        vm: AthleteProfileViewModel(athlete: athlete, store: store)
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToRelayBuilder) {
                RelayBuilderView(
                    vm: RelayBuilderViewModel(store: store)
                )
            }
            .onAppear {
                vm.load()
            }
        }
    }

    // MARK: – Event Section

    private var eventSection: some View {
        Section("Event") {
            // 1. Race type toggle: Individual / Relay
            Picker("Type", selection: $vm.raceType) {
                ForEach(RaceTypeSelection.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

            // 2. Gender filter
            HStack(spacing: 10) {
                genderFilterButton("Mixed", gender: nil)
                genderFilterButton("M", gender: .male)
                genderFilterButton("F", gender: .female)
            }
            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

            // 3. Distance picker
            if vm.raceType == .individual {
                Picker("Distance", selection: $vm.eventType) {
                    ForEach(RaceSetupViewModel.individualEventTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if vm.eventType == .custom {
                    HStack {
                        Text("Distance (m)")
                        Spacer()
                        TextField("e.g. 1500", text: $vm.customDistance)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            } else if vm.raceType == .relay {
                Picker("Relay Distance", selection: $vm.eventType) {
                    ForEach(RaceSetupViewModel.relayEventTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

                if let legDist = vm.eventType.legDistanceMeters {
                    HStack {
                        Text("Format").foregroundStyle(.secondary)
                        Spacer()
                        Text("4 runners \u{00D7} \(legDist)m")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 4. Race Name
            TextField("Race Name (optional)", text: $vm.raceName)
                .onChange(of: vm.eventType) { newType in
                    if isAutoGeneratedName {
                        vm.raceName = "\(vm.genderPrefix) \(newType.displayName)"
                    }
                }
                .onChange(of: vm.genderFilter) { _ in
                    if isAutoGeneratedName {
                        vm.raceName = "\(vm.genderPrefix) \(vm.eventType.displayName)"
                    }
                }

            // 5. Heat quick-label chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Heat 1", "Heat 2", "Heat 3", "Semifinal", "Final"], id: \.self) { label in
                        Button(label) {
                            vm.raceName = "\(vm.genderPrefix) \(vm.eventType.displayName) \(label)"
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .tint(Theme.runsmithPink)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            // 6. Track Length + Splits per Lap
            if vm.raceType == .individual {
                HStack {
                    Text("Track Length").foregroundStyle(.secondary)
                    Spacer()
                    Text("400m (outdoor)").foregroundStyle(.secondary)
                }
                Stepper("Splits per Lap: \(vm.splitsPerLap)", value: $vm.splitsPerLap, in: 1...4)
            }
        }
    }

    // MARK: – Athlete Section

    @ViewBuilder
    private var athleteSection: some View {
        if vm.raceType == .relay {
            relayAthleteSection
        } else {
            regularAthleteSection
        }
    }

    // MARK: Regular Athlete Section

    private var regularAthleteSection: some View {
        Section {
            if !vm.availableAthletes.isEmpty {
                TextField("Search athletes", text: $vm.athleteSearchText)
                    .autocorrectionDisabled()
            }

            ForEach(vm.filteredAthletes) { athlete in
                let selected = vm.selectedAthleteIds.contains(athlete.id)
                athleteRow(athlete: athlete, selected: selected) {
                    vm.toggleAthlete(athlete.id)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vm.delete(athlete: athlete)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editName = athlete.name
                        editTeam = athlete.teamName ?? ""
                        editColorHex = athlete.colorHex
                        editGender = athlete.gender
                        athleteToEdit = athlete
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .opacity(vm.isAthleteCapReached && !selected ? 0.4 : 1.0)
            }
            .onMove { vm.moveAthletes(from: $0, to: $1) }
            .deleteDisabled(true)

            Button {
                showAddAthlete = true
            } label: {
                Label("New Athlete", systemImage: "person.badge.plus")
            }
        } header: {
            HStack {
                Text("Athletes")
                Spacer()
                if !vm.selectedAthleteIds.isEmpty {
                    Text("\(vm.selectedAthleteIds.count)/\(RaceSetupViewModel.maxIndividualAthletes) selected")
                        .font(.caption)
                        .foregroundStyle(vm.isAthleteCapReached ? .orange : Theme.runsmithPink)
                }
            }
        }
    }

    // MARK: – Shared Athlete Row

    /// Row with gender bar, color dot, name, info button, and selection indicator.
    /// Tapping anywhere on the row (except the ⓘ button) toggles selection.
    private func athleteRow(athlete: Athlete, selected: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            // Gender color bar
            Rectangle()
                .fill(Theme.genderColor(athlete.gender))
                .frame(width: 4)
                .clipShape(Capsule())
                .padding(.trailing, 10)

            // Color dot
            Circle()
                .fill(Color(hex: athlete.colorHex))
                .frame(width: 12, height: 12)
                .padding(.trailing, 8)

            // Name + team
            VStack(alignment: .leading, spacing: 1) {
                Text(athlete.name).font(.body)
                if let team = athlete.teamName {
                    Text(team).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            // Info button — opens profile
            Button {
                profileAthlete = athlete
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .font(.body)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Selection checkmark
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Theme.runsmithPink : Color(.quaternaryLabel))
                .font(.title3)
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    // MARK: Relay Athlete Section

    private var relayAthleteSection: some View {
        Group {
            // Leg order section (assigned athletes, drag to reorder)
            Section {
                ForEach(Array(vm.relayAthletesOrdered.enumerated()), id: \.element.id) { i, athlete in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Theme.runsmithPink)
                            .clipShape(Circle())
                        Rectangle()
                            .fill(Theme.genderColor(athlete.gender))
                            .frame(width: 4)
                            .clipShape(Capsule())
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 12, height: 12)
                        Text(athlete.name)
                            .font(.body)
                        Spacer()
                        Button {
                            vm.toggleAthlete(athlete.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.quaternary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { vm.moveRelayLeg(from: $0, to: $1) }
                .deleteDisabled(true)

                // Empty leg placeholders
                ForEach(vm.relayAthletesOrdered.count..<4, id: \.self) { i in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color(.quaternaryLabel))
                            .clipShape(Circle())
                        Text("Tap an athlete below")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                HStack {
                    Text("Leg Order")
                    Spacer()
                    let count = vm.relayAthletesOrdered.count
                    Text("\(count)/4 assigned")
                        .font(.caption)
                        .foregroundStyle(count == 4 ? Theme.runsmithPink : .secondary)
                }
            } footer: {
                if !vm.relayAthletesOrdered.isEmpty {
                    Text("Drag to reorder legs")
                        .font(.caption)
                }
            }

            // Source picker + content
            Section {
                Picker("Pick From", selection: $relaySource) {
                    ForEach(RelaySource.allCases, id: \.self) { src in
                        Text(src.rawValue).tag(src)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

                if relaySource == .savedTeams {
                    savedTeamsContent
                } else {
                    athletesContent
                }
            } header: {
                Text(relaySource == .savedTeams ? "Saved Teams" : "Available Athletes")
            }
        }
    }

    // MARK: – Relay: Saved Teams Content

    @ViewBuilder
    private var savedTeamsContent: some View {
        let matching = vm.matchingSavedTeams
        if matching.isEmpty {
            // Combined empty state + build button in one row
            Button {
                navigateToRelayBuilder = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No saved teams for \(vm.eventType.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Build New Team")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.runsmithPink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        } else {
            ForEach(matching) { team in
                Button {
                    vm.loadSavedTeam(team)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(team.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(team.gender.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        savedTeamMembersRow(team.athleteIds)
                    }
                }
            }

            // Build New Team — uses state-based navigation
            Button {
                navigateToRelayBuilder = true
            } label: {
                Label("Build New Team", systemImage: "plus.circle")
            }
        }
    }

    private func savedTeamMembersRow(_ athleteIds: [UUID]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(athleteIds.enumerated()), id: \.offset) { i, id in
                if let athlete = vm.athlete(for: id) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 8, height: 8)
                        Text(athlete.firstName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if i < athleteIds.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: – Relay: Athletes Content

    @ViewBuilder
    private var athletesContent: some View {
        let unselected = vm.filteredAthletes.filter { !vm.selectedAthleteIds.contains($0.id) }
        if unselected.isEmpty && vm.availableAthletes.isEmpty {
            Text("No athletes yet — add one below")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if unselected.isEmpty {
            Text("All athletes assigned")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(unselected) { athlete in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.genderColor(athlete.gender))
                        .frame(width: 4)
                        .clipShape(Capsule())
                        .padding(.trailing, 10)
                    Circle()
                        .fill(Color(hex: athlete.colorHex))
                        .frame(width: 12, height: 12)
                        .padding(.trailing, 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(athlete.name).font(.body)
                        if let team = athlete.teamName {
                            Text(team).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.runsmithPink)
                        .font(.title3)
                }
                .contentShape(Rectangle())
                .onTapGesture { vm.toggleAthlete(athlete.id) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vm.delete(athlete: athlete)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editName = athlete.name
                        editTeam = athlete.teamName ?? ""
                        editColorHex = athlete.colorHex
                        athleteToEdit = athlete
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }

        Button {
            showAddAthlete = true
        } label: {
            Label("New Athlete", systemImage: "person.badge.plus")
        }
    }

    // MARK: – Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            // Save — compact, understated
            Button {
                guard vm.saveRace() != nil else { return }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.runsmithPink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Theme.runsmithPink.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!vm.isValid)
            .opacity(vm.isValid ? 1.0 : 0.4)

            // Start Race — primary, full-width
            Button {
                guard let race = vm.startRace() else { return }
                createdRace = race
                let athletes = (try? store.fetchAthletes()) ?? []
                liveTimingVM = LiveTimingViewModel(
                    race: race, athletes: athletes, store: store, cache: cache
                )
                navigateToLiveTiming = true
            } label: {
                Text(vm.raceType == .relay ? "Start Relay" : "Start Race")
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .disabled(!vm.isValid)
        }
        .glassActionBar()
    }

    // MARK: – Edit Athlete Sheet

    private func editAthleteSheet(athlete: Athlete) -> some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (required)", text: $editName)
                    TextField("Team (optional)", text: $editTeam)
                    genderPicker(selection: $editGender)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(RaceSetupViewModel.colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if editColorHex == hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { editColorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Athlete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { athleteToEdit = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let gender = editGender else { return }
                        vm.update(athlete: athlete, name: editName, teamName: editTeam, colorHex: editColorHex, gender: gender)
                        athleteToEdit = nil
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty || editGender == nil)
                }
            }
        }
    }

    // MARK: – Gender Filter

    private func genderFilterButton(_ label: String, gender: Gender?) -> some View {
        Button {
            vm.genderFilter = gender
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    vm.genderFilter == gender
                        ? (gender.map { Theme.genderTint($0) } ?? Theme.runsmithPink)
                        : Color(.tertiarySystemFill)
                )
                .foregroundStyle(vm.genderFilter == gender ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var isAutoGeneratedName: Bool {
        if vm.raceName.isEmpty { return true }
        let events = EventType.allCases.map(\.displayName)
        let prefixes = ["Boys ", "Girls ", "Mixed ", ""]
        let suffixes = ["", " Heat 1", " Heat 2", " Heat 3", " Semifinal", " Final"]
        for event in events {
            for prefix in prefixes {
                for suffix in suffixes {
                    if vm.raceName == "\(prefix)\(event)\(suffix)" { return true }
                }
            }
        }
        return false
    }

    // MARK: – Gender Picker (mandatory, M=blue, F=pink)

    private func genderPicker(selection: Binding<Gender?>) -> some View {
        HStack(spacing: 12) {
            Text("Gender").foregroundStyle(.secondary)
            Spacer()
            ForEach(Gender.allCases, id: \.self) { g in
                Button(g.rawValue) {
                    selection.wrappedValue = g
                }
                .buttonStyle(.bordered)
                .tint(selection.wrappedValue == g ? Theme.genderTint(g) : .secondary)
            }
        }
    }

    // MARK: – Add Athlete Sheet

    private var addAthleteSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (required)", text: $vm.newAthleteName)
                    TextField("Team (optional)", text: $vm.newAthleteTeam)
                    genderPicker(selection: $vm.newAthleteGender)
                }
            }
            .navigationTitle("New Athlete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddAthlete = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        vm.addNewAthlete()
                        showAddAthlete = false
                    }
                    .disabled(vm.newAthleteName.trimmingCharacters(in: .whitespaces).isEmpty || vm.newAthleteGender == nil)
                }
            }
        }
    }
}
