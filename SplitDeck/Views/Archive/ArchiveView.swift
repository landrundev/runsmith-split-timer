import SwiftUI

struct ArchiveView: View {
    @ObservedObject var vm: ArchiveViewModel

    @State private var meetToDelete: Meet? = nil
    @State private var raceToDelete: Race? = nil
    @State private var athleteToDelete: Athlete? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        List {
            if vm.archivedMeets.isEmpty && vm.archivedQuickRaces.isEmpty && vm.archivedAthletes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Archive is Empty")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Archived meets, races, and athletes will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                if !vm.archivedMeets.isEmpty {
                    Section("Meets") {
                        ForEach(vm.archivedMeets) { meet in
                            meetRow(meet)
                        }
                    }
                }

                if !vm.archivedQuickRaces.isEmpty {
                    Section("Quick Races") {
                        ForEach(vm.archivedQuickRaces) { race in
                            raceRow(race)
                        }
                    }
                }

                if !vm.archivedAthletes.isEmpty {
                    Section("Athletes") {
                        ForEach(vm.archivedAthletes) { athlete in
                            athleteRow(athlete)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Archive")
        .confirmationDialog(
            "Permanently delete \"\(meetToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { meetToDelete != nil },
                set: { if !$0 { meetToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: meetToDelete
        ) { meet in
            Button("Delete Meet & All Races", role: .destructive) {
                vm.delete(meet: meet)
                meetToDelete = nil
            }
            Button("Cancel", role: .cancel) { meetToDelete = nil }
        } message: { _ in
            Text("This will permanently delete the meet and all its races and splits.")
        }
        .confirmationDialog(
            "Permanently delete \"\(raceToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { raceToDelete != nil },
                set: { if !$0 { raceToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: raceToDelete
        ) { race in
            Button("Delete Race & Splits", role: .destructive) {
                vm.delete(race: race)
                raceToDelete = nil
            }
            Button("Cancel", role: .cancel) { raceToDelete = nil }
        }
        .confirmationDialog(
            "Permanently delete \(athleteToDelete?.name ?? "Athlete")?",
            isPresented: Binding(
                get: { athleteToDelete != nil },
                set: { if !$0 { athleteToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let athlete = athleteToDelete {
                    vm.delete(athlete: athlete)
                }
                athleteToDelete = nil
            }
        } message: {
            Text("This will permanently remove this athlete and cannot be undone.")
        }
        .onAppear { vm.load() }
    }

    // MARK: – Rows

    private func meetRow(_ meet: Meet) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(meet.name).font(.headline)
            HStack {
                Text(Self.dateFormatter.string(from: meet.date))
                if let loc = meet.location {
                    Text("·")
                    Text(loc)
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                vm.unarchive(meet: meet)
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                meetToDelete = meet
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func raceRow(_ race: Race) -> some View {
        HStack(spacing: 0) {
            raceGenderBar(race)
                .padding(.trailing, 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(race.name).font(.headline)
                Text(race.startedAt.map { Self.dateFormatter.string(from: $0) } ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                vm.unarchive(race: race)
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                raceToDelete = race
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func athleteRow(_ athlete: Athlete) -> some View {
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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                vm.unarchive(athlete: athlete)
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                athleteToDelete = athlete
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func raceGenderBar(_ race: Race) -> some View {
        let genders = race.athleteIds.compactMap { id in
            vm.allAthletes.first(where: { $0.id == id })?.gender
        }
        let hasMale = genders.contains(.male)
        let hasFemale = genders.contains(.female)

        let fill: AnyShapeStyle
        if hasMale && hasFemale {
            fill = AnyShapeStyle(LinearGradient(
                colors: [.blue, Color(hex: "#FF5CA1")],
                startPoint: .top, endPoint: .bottom
            ))
        } else if hasMale {
            fill = AnyShapeStyle(Color.blue)
        } else if hasFemale {
            fill = AnyShapeStyle(Color(hex: "#FF5CA1"))
        } else {
            fill = AnyShapeStyle(Color(.quaternaryLabel))
        }

        return Rectangle()
            .fill(fill)
            .frame(width: 4)
            .clipShape(Capsule())
    }
}
