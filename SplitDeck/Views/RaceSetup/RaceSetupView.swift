import SwiftUI

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

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                athleteSection
            }
            .navigationTitle("Race Setup")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
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
            .onAppear { vm.load() }
        }
    }

    // MARK: – Event Section

    private var eventSection: some View {
        Section("Event") {
            // Race type toggle: Individual / Relay
            Picker("Type", selection: $vm.raceType) {
                ForEach(RaceTypeSelection.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Distance picker — options depend on race type
            if vm.raceType == .individual {
                Picker("Distance", selection: $vm.eventType) {
                    ForEach(RaceSetupViewModel.individualEventTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

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
            } else {
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

            TextField("Race Name (optional)", text: $vm.raceName)
                .onChange(of: vm.eventType) { newType in
                    // Update name if it's still an auto-generated value or empty
                    let autoNames = EventType.allCases.map(\.displayName)
                    if vm.raceName.isEmpty || autoNames.contains(vm.raceName) {
                        vm.raceName = newType.displayName
                    }
                }

            // Quick-label chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Heat 1", "Heat 2", "Heat 3", "Semifinal", "Final"], id: \.self) { label in
                        Button(label) {
                            vm.raceName = "\(vm.eventType.displayName) \(label)"
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

            if vm.raceType == .individual {
                HStack {
                    Text("Track Length").foregroundStyle(.secondary)
                    Spacer()
                    Text("400m (outdoor)").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Splits per Lap").foregroundStyle(.secondary)
                    Spacer()
                    Text("1").foregroundStyle(.secondary)
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
        Section {
            if !vm.availableAthletes.isEmpty {
                TextField("Search athletes", text: $vm.athleteSearchText)
                    .autocorrectionDisabled()
            }

            ForEach(vm.filteredAthletes) { athlete in
                HStack {
                    Circle()
                        .fill(Color(hex: athlete.colorHex))
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(athlete.name).font(.body)
                        if let team = athlete.teamName {
                            Text(team).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if vm.selectedAthleteIds.contains(athlete.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.runsmithPink)
                            .fontWeight(.semibold)
                    }
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
                    Text("\(vm.selectedAthleteIds.count) selected")
                        .font(.caption)
                        .foregroundStyle(Theme.runsmithPink)
                }
            }
        }
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

            // Available athletes section
            Section("Available Athletes") {
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
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: athlete.colorHex))
                                .frame(width: 12, height: 12)
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
        }
    }

    // MARK: – Start Button

    private var startButton: some View {
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
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.runsmithPink)
        .disabled(!vm.isValid)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: – Edit Athlete Sheet

    private func editAthleteSheet(athlete: Athlete) -> some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (required)", text: $editName)
                    TextField("Team (optional)", text: $editTeam)
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
                        vm.update(athlete: athlete, name: editName, teamName: editTeam, colorHex: editColorHex)
                        athleteToEdit = nil
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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
                    .disabled(vm.newAthleteName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
