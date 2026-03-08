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

    // Collapsible event section
    @State private var eventSectionExpanded = true

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
                if vm.existingRaceId != nil {
                    eventSectionExpanded = false
                }
            }
        }
    }

    // MARK: – Event Section

    private var eventSection: some View {
        Section {
            DisclosureGroup(isExpanded: $eventSectionExpanded) {
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
                            .foregroundStyle(Theme.textSecondary)
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
                        Text("Format").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("4 runners \u{00D7} \(legDist)m")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if vm.supportsIntermediateSplits {
                    Toggle(isOn: Binding(
                        get: { vm.splitsPerLap == 2 },
                        set: { vm.splitsPerLap = $0 ? 2 : 1 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Record Intermediate Splits")
                            if let label = vm.intermediateSplitLabel {
                                Text("Record a \(label) split within each leg")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .tint(Theme.runsmithPink)
                }
            }

            // 4. Race Name
            TextField("Race Name (optional)", text: $vm.raceName)
                .onChange(of: vm.eventType) { newType in
                    // Reset intermediate splits when switching relay types
                    if newType.isRelay && !(newType == .relay4x1600 || newType == .relay4x3200) {
                        vm.splitsPerLap = 1
                    }
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
                    Text("Track Length").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("400m (outdoor)").foregroundStyle(Theme.textSecondary)
                }
                Stepper("Splits per Lap: \(vm.splitsPerLap)", value: $vm.splitsPerLap, in: 1...4)
            }
            } label: {
                HStack {
                    Text("Event").fontWeight(.medium)
                    if !eventSectionExpanded {
                        Spacer()
                        Text(vm.raceName.isEmpty ? vm.eventType.displayName : vm.raceName)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
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
        Group {
            // Roster section — selected athletes
            if !vm.selectedAthleteIds.isEmpty {
                Section {
                    let selected = vm.filteredAthletes.filter { vm.selectedAthleteIds.contains($0.id) }
                    ForEach(selected) { athlete in
                        athleteRow(athlete: athlete, selected: true) {
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
                            .tint(Theme.genderMale)
                        }
                    }
                } header: {
                    HStack {
                        Text("Roster")
                        Spacer()
                        Text("\(vm.selectedAthleteIds.count)/\(RaceSetupViewModel.maxIndividualAthletes) selected")
                            .font(.caption)
                            .foregroundStyle(vm.isAthleteCapReached ? .orange : Theme.runsmithPink)
                    }
                }
            }

            // Athletes section — available unselected athletes
            Section {
                if !vm.availableAthletes.isEmpty {
                    TextField("Search athletes", text: $vm.athleteSearchText)
                        .autocorrectionDisabled()
                }

                let unselected = vm.filteredAthletes.filter { !vm.selectedAthleteIds.contains($0.id) }
                ForEach(unselected) { athlete in
                    athleteRow(athlete: athlete, selected: false) {
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
                        .tint(Theme.genderMale)
                    }
                    .opacity(vm.isAthleteCapReached ? 0.4 : 1.0)
                }
                .onMove { vm.moveAthletes(from: $0, to: $1) }
                .deleteDisabled(true)

                Button {
                    showAddAthlete = true
                } label: {
                    Label("New Athlete", systemImage: "person.badge.plus")
                }
            } header: {
                Text("Athletes")
            }
        }
    }

    // MARK: – Shared Athlete Row

    /// Row with gender bar, color dot, name, info button, and selection indicator.
    /// Tapping anywhere on the row (except the info button) toggles selection.
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
                Text(athlete.name)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                if let team = athlete.teamName {
                    Text(team)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 8)

            // Info button — opens profile
            Button {
                profileAthlete = athlete
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.accentPrimary)
                    .font(.body)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Selection checkmark
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Theme.runsmithPink : Theme.textMuted)
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
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button {
                            vm.toggleAthlete(athlete.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textMuted)
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
                            .background(Theme.textMuted)
                            .clipShape(Circle())
                        Text("Tap an athlete below")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            } header: {
                HStack {
                    Text("Leg Order")
                    Spacer()
                    let count = vm.relayAthletesOrdered.count
                    Text("\(count)/4 assigned")
                        .font(.caption)
                        .foregroundStyle(count == 4 ? Theme.runsmithPink : Theme.textSecondary)
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
                        .foregroundStyle(Theme.textSecondary)
                    Text("No saved \(vm.genderPrefix.lowercased()) teams for \(vm.eventType.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
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
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(team.gender.displayName)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
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
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .foregroundStyle(Theme.textSecondary)
    }

    // MARK: – Relay: Athletes Content

    @ViewBuilder
    private var athletesContent: some View {
        let unselected = vm.filteredAthletes.filter { !vm.selectedAthleteIds.contains($0.id) }
        if unselected.isEmpty && vm.availableAthletes.isEmpty {
            Text("No athletes yet \u{2014} add one below")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        } else if unselected.isEmpty {
            Text("All athletes assigned")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
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
                        Text(athlete.name)
                            .font(.body)
                            .foregroundStyle(Theme.textPrimary)
                        if let team = athlete.teamName {
                            Text(team)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
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
                    .tint(Theme.genderMale)
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
            // Save
            Button {
                guard vm.saveRace() != nil else { return }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
            }
            .buttonStyle(GlassSecondaryButtonStyle())
            .disabled(!vm.isValid)
            .frame(maxWidth: vm.existingRaceId != nil ? 120 : .infinity)

            // Start Race
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
            .buttonStyle(GlassPrimaryButtonStyle(color: .green))
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
                .foregroundStyle(vm.genderFilter == gender ? .white : Theme.textPrimary)
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
            Text("Gender").foregroundStyle(Theme.textSecondary)
            Spacer()
            ForEach(Gender.allCases, id: \.self) { g in
                Button(g.rawValue) {
                    selection.wrappedValue = g
                }
                .buttonStyle(.bordered)
                .tint(selection.wrappedValue == g ? Theme.genderTint(g) : Theme.textTertiary)
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
