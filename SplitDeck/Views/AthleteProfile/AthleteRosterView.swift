import SwiftUI

struct AthleteRosterView: View {
    let store: SplitDeckStore
    @State private var athletes: [Athlete] = []
    @State private var searchText = ""
    @State private var genderFilter: Gender? = nil

    // Add athlete
    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newTeam = ""
    @State private var newGender: Gender? = nil
    @State private var newColorHex = RaceSetupViewModel.colorPalette[0]

    // Edit athlete
    @State private var athleteToEdit: Athlete? = nil
    @State private var editName = ""
    @State private var editTeam = ""
    @State private var editGender: Gender? = nil
    @State private var editColorHex = ""

    // Delete athlete
    @State private var athleteToDelete: Athlete? = nil

    // Import from file
    @State private var showRosterImport = false

    private var filteredAthletes: [Athlete] {
        var result = athletes
        if let gender = genderFilter {
            result = result.filter { $0.gender == gender }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        List {
            if athletes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Athletes Yet")
                        .font(.headline)
                    Text("Tap + to add your first athlete.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                // Gender filter row
                genderFilterRow

                ForEach(filteredAthletes) { athlete in
                    NavigationLink {
                        AthleteProfileView(
                            vm: AthleteProfileViewModel(athlete: athlete, store: store),
                            store: store,
                            onDelete: { refreshAthletes() }
                        )
                    } label: {
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
                                    Text(team)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            athleteToDelete = athlete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editName = athlete.name
                            editTeam = athlete.teamName ?? ""
                            editGender = athlete.gender
                            editColorHex = athlete.colorHex
                            athleteToEdit = athlete
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Athletes")
        .searchable(text: $searchText, prompt: "Search athletes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        newName = ""
                        newTeam = ""
                        newGender = nil
                        newColorHex = RaceSetupViewModel.colorPalette[athletes.count % RaceSetupViewModel.colorPalette.count]
                        showAddSheet = true
                    } label: {
                        Label("Add Athlete", systemImage: "plus")
                    }

                    Button {
                        showRosterImport = true
                    } label: {
                        Label("Import from File", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addAthleteSheet
        }
        .sheet(item: $athleteToEdit) { athlete in
            editAthleteSheet(athlete: athlete)
        }
        .confirmationDialog(
            "Delete \(athleteToDelete?.name ?? "Athlete")?",
            isPresented: Binding(
                get: { athleteToDelete != nil },
                set: { if !$0 { athleteToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let athlete = athleteToDelete {
                    try? store.delete(athleteId: athlete.id)
                    refreshAthletes()
                }
                athleteToDelete = nil
            }
        } message: {
            Text("This will permanently remove this athlete and cannot be undone.")
        }
        .sheet(isPresented: $showRosterImport) {
            RosterImportView(store: store)
        }
        .onChange(of: showRosterImport) { showing in
            if !showing { refreshAthletes() }
        }
        .onAppear { refreshAthletes() }
    }

    // MARK: – Add Athlete Sheet

    private var addAthleteSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (required)", text: $newName)
                    TextField("Team (optional)", text: $newTeam)
                    genderPicker(selection: $newGender)
                }
                Section("Color") {
                    colorPaletteGrid(selection: $newColorHex)
                }
            }
            .navigationTitle("New Athlete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let color = newColorHex
                        let athlete = Athlete(
                            name: newName.trimmingCharacters(in: .whitespaces),
                            teamName: newTeam.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newTeam,
                            colorHex: color,
                            gender: newGender
                        )
                        try? store.save(athlete)
                        refreshAthletes()
                        showAddSheet = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newGender == nil)
                }
            }
        }
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
                    colorPaletteGrid(selection: $editColorHex)
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
                        let updated = Athlete(
                            id: athlete.id,
                            name: editName.trimmingCharacters(in: .whitespaces),
                            teamName: editTeam.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editTeam,
                            colorHex: editColorHex,
                            notes: athlete.notes,
                            gender: editGender
                        )
                        try? store.save(updated)
                        refreshAthletes()
                        athleteToEdit = nil
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty || editGender == nil)
                }
            }
        }
    }

    // MARK: – Shared Components

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

    private var genderFilterRow: some View {
        HStack(spacing: 8) {
            Text("Filter").foregroundStyle(.secondary)
            Spacer()
            genderFilterButton("All", gender: nil)
            genderFilterButton("M", gender: .male)
            genderFilterButton("F", gender: .female)
        }
    }

    private func genderFilterButton(_ label: String, gender: Gender?) -> some View {
        Button(label) {
            genderFilter = genderFilter == gender ? nil : gender
        }
        .buttonStyle(.bordered)
        .tint(genderFilter == gender ? (gender.map { Theme.genderTint($0) } ?? Theme.runsmithPink) : .secondary)
    }

    private func colorPaletteGrid(selection: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(RaceSetupViewModel.colorPalette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if selection.wrappedValue == hex {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection.wrappedValue = hex }
            }
        }
        .padding(.vertical, 4)
    }

    private func refreshAthletes() {
        athletes = (try? store.fetchAthletes()) ?? []
    }
}
