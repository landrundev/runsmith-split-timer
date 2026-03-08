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

    // Coach name
    @State private var coachName = CoachIdentity.name ?? ""
    @State private var isEditingCoachName = false

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

    private var coachNameSection: some View {
        Section {
            if isEditingCoachName {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(Theme.runsmithPink)
                        .frame(width: 24)

                    TextField("Enter your name", text: $coachName)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit { saveCoachName() }

                    Button("Save") {
                        saveCoachName()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.runsmithPink)
                }
            } else {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(Theme.runsmithPink)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(coachName.isEmpty ? "Tap to set your name" : coachName)
                            .foregroundStyle(coachName.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                        if !coachName.isEmpty {
                            Text("Coach Name")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.runsmithPink)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isEditingCoachName = true
                }
            }
        } header: {
            Text("Coach")
        }
    }

    private func saveCoachName() {
        let trimmed = coachName.trimmingCharacters(in: .whitespaces)
        coachName = trimmed
        CoachIdentity.name = trimmed.isEmpty ? nil : trimmed
        isEditingCoachName = false
    }

    var body: some View {
        List {
            coachNameSection

            if athletes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textSecondary)
                    Text("No Athletes Yet")
                        .font(.headline)
                    Text("Tap + to add your first athlete.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
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
                                        .foregroundStyle(Theme.textSecondary)
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
                        .tint(Theme.genderMale)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            try? store.archive(athleteId: athlete.id)
                            refreshAthletes()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
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
                        guard let gender = newGender else { return }
                        let color = newColorHex
                        let athlete = Athlete(
                            name: newName.trimmingCharacters(in: .whitespaces),
                            teamName: newTeam.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newTeam,
                            colorHex: color,
                            gender: gender
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
                        guard let gender = editGender else { return }
                        let updated = Athlete(
                            id: athlete.id,
                            name: editName.trimmingCharacters(in: .whitespaces),
                            teamName: editTeam.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editTeam,
                            colorHex: editColorHex,
                            notes: athlete.notes,
                            gender: gender
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
            Text("Gender").foregroundStyle(Theme.textSecondary)
            Spacer()
            ForEach(Gender.allCases, id: \.self) { g in
                Button(g.rawValue) {
                    selection.wrappedValue = g
                }
                .buttonStyle(.bordered)
                .tint(selection.wrappedValue == g ? Theme.genderTint(g) : Theme.textSecondary)
            }
        }
    }

    private var genderFilterRow: some View {
        HStack(spacing: 8) {
            Text("Filter").foregroundStyle(Theme.textSecondary)
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
        .tint(genderFilter == gender ? (gender.map { Theme.genderTint($0) } ?? Theme.runsmithPink) : Theme.textSecondary)
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
