import SwiftUI

struct AthleteProfileView: View {
    @ObservedObject var vm: AthleteProfileViewModel
    var store: SplitDeckStore? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Edit
    @State private var showEditSheet = false
    @State private var editName = ""
    @State private var editTeam = ""
    @State private var editGender: Gender? = nil
    @State private var editColorHex = ""

    // Delete
    @State private var showDeleteConfirm = false
    @State private var raceToDelete: AthleteRaceResult? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        List {
            athleteHeader
            if !vm.personalBests.isEmpty {
                personalBestsSection
            }
            raceHistorySection
        }
        .navigationTitle(vm.athlete.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            editName = vm.athlete.name
                            editTeam = vm.athlete.teamName ?? ""
                            editGender = vm.athlete.gender
                            editColorHex = vm.athlete.colorHex
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editAthleteSheet
        }
        .confirmationDialog(
            "Delete \(vm.athlete.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                try? vm.deleteAthlete()
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This will permanently remove this athlete and cannot be undone.")
        }
        .confirmationDialog(
            "Delete \"\(raceToDelete?.raceName ?? "")\"?",
            isPresented: Binding(
                get: { raceToDelete != nil },
                set: { if !$0 { raceToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Race & Splits", role: .destructive) {
                if let result = raceToDelete {
                    vm.deleteRace(id: result.id)
                }
                raceToDelete = nil
            }
        } message: {
            Text("This will permanently delete the race and all its splits.")
        }
        .onAppear { vm.load() }
    }

    // MARK: – Edit Sheet

    private var editAthleteSheet: some View {
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
                    Button("Cancel") { showEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let gender = editGender else { return }
                        let updated = Athlete(
                            id: vm.athlete.id,
                            name: editName.trimmingCharacters(in: .whitespaces),
                            teamName: editTeam.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editTeam,
                            colorHex: editColorHex,
                            notes: vm.athlete.notes,
                            gender: gender
                        )
                        vm.save(updated)
                        vm.load()
                        showEditSheet = false
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty || editGender == nil)
                }
            }
        }
    }

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

    // MARK: – Header

    private var athleteHeader: some View {
        Section {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.genderColor(vm.athlete.gender))
                    .frame(width: 4)
                    .clipShape(Capsule())
                    .padding(.trailing, 10)
                Circle()
                    .fill(Color(hex: vm.athlete.colorHex))
                    .frame(width: 40, height: 40)
                    .padding(.trailing, 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.athlete.name)
                        .font(.title3.weight(.bold))
                    if let team = vm.athlete.teamName {
                        Text(team)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(vm.raceHistory.count)")
                        .font(.title3.weight(.bold))
                    Text("Races")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: – Personal Bests

    private var personalBestsSection: some View {
        Section("Personal Bests") {
            ForEach(vm.personalBests, id: \.eventType) { entry in
                HStack {
                    Text(entry.eventType.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(entry.timeMs.formattedSplitTime)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                }
            }
        }
    }

    // MARK: – Race History

    private var raceHistorySection: some View {
        Section("Race History") {
            if vm.raceHistory.isEmpty {
                Text("No completed races yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.raceHistory) { result in
                    if result.cumulativeTimesMs.isEmpty {
                        raceResultHeader(result)
                            .padding(.vertical, 2)
                    } else {
                        DisclosureGroup {
                            splitDetailsView(result)
                        } label: {
                            raceResultHeader(result)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    if let i = offsets.first {
                        raceToDelete = vm.raceHistory[i]
                    }
                }
            }
        }
    }

    private func raceResultHeader(_ result: AthleteRaceResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.raceName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(result.eventType.displayName)
                    if let meetName = result.meetName {
                        Text("\u{00B7}")
                        Text(meetName)
                            .foregroundStyle(Theme.runsmithPink.opacity(0.8))
                    }
                    if let date = result.date {
                        Text("\u{00B7}")
                        Text(Self.dateFormatter.string(from: date))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let time = result.finalTimeMs {
                    Text(time.formattedSplitTime)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                } else if result.isUnlimited {
                    Text("\(result.splitCount) splits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("DNF")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                }
                if let place = result.place {
                    Text(placeString(place))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(placeColor(place))
                }
            }
        }
    }

    private func splitDetailsView(_ result: AthleteRaceResult) -> some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("Split")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Cumulative")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Lap")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            ForEach(Array(result.cumulativeTimesMs.enumerated()), id: \.offset) { i, cumMs in
                HStack {
                    Text(i < result.splitLabels.count ? result.splitLabels[i] : "Split \(i + 1)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(cumMs.formattedSplitTime)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(i < result.lapTimesMs.count ? result.lapTimesMs[i].formattedSplitTime : "\u{2014}")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.monospacedDigit())
                .padding(.vertical, 2)

                if i < result.cumulativeTimesMs.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func placeString(_ place: Int) -> String {
        let suffix: String
        switch place % 10 {
        case 1 where place % 100 != 11: suffix = "st"
        case 2 where place % 100 != 12: suffix = "nd"
        case 3 where place % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(place)\(suffix) place"
    }

    private func placeColor(_ place: Int) -> Color {
        switch place {
        case 1: return Color(hex: "#B8960C")  // gold
        case 2: return Color(hex: "#6E6E6E")  // silver
        case 3: return Color(hex: "#8B4513")  // bronze
        default: return .secondary
        }
    }
}
