import SwiftUI

struct MeetDetailView: View {
    @ObservedObject var vm: MeetDetailViewModel
    let store: SplitDeckStore
    let cache: RaceStateCache

    @State private var showAddRace = false
    @State private var raceToDelete: Race? = nil
    @State private var genderFilter: Gender? = nil

    private var filteredRaces: [Race] {
        guard let gender = genderFilter else { return vm.races }
        return vm.races.filter { race in
            let genders = race.athleteIds.compactMap { id in
                vm.athletes.first(where: { $0.id == id })?.gender
            }
            return genders.contains(gender)
        }
    }

    var body: some View {
        List {
            if vm.races.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Races")
                        .font(.headline)
                    Text("Tap + Add Race to create one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                genderFilterRow

                ForEach(filteredRaces) { race in
                    raceRow(race)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                raceToDelete = race
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                vm.archive(race: race)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vm.meet.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("+ Add Race") { showAddRace = true }
            }
        }
        .sheet(isPresented: $showAddRace, onDismiss: { vm.load() }) {
            RaceSetupView(
                vm: RaceSetupViewModel(meetId: vm.meet.id, store: store),
                store: store,
                cache: cache
            )
        }
        .confirmationDialog(
            "Delete \"\(raceToDelete?.name ?? "")\"?",
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
        } message: { _ in
            Text("All recorded splits for this race will be permanently deleted.")
        }
        .onAppear { vm.load() }
    }

    @ViewBuilder
    private func raceRow(_ race: Race) -> some View {
        let destination = raceDestination(race)
        NavigationLink(destination: destination) {
            HStack(spacing: 0) {
                raceGenderBar(race)
                    .padding(.trailing, 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(race.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(race.eventType.displayName)
                        if race.status == .notStarted && !race.athleteIds.isEmpty {
                            Text("·")
                            Text("\(race.athleteIds.count) athlete\(race.athleteIds.count == 1 ? "" : "s")")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(race.status)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func raceDestination(_ race: Race) -> some View {
        switch race.status {
        case .notStarted:
            let setupVM = RaceSetupViewModel(meetId: vm.meet.id, store: store, existingRaceId: race.id)
            RaceSetupView(vm: setupVM, store: store, cache: cache)

        case .inProgress:
            let athletes = (try? store.fetchAthletes()) ?? []
            let liveVM = LiveTimingViewModel(race: race, athletes: athletes, store: store, cache: cache)
            LiveTimingView(vm: liveVM, cache: cache)

        case .completed:
            let athletes = (try? store.fetchAthletes()) ?? []
            let splits   = (try? store.fetchSplits(for: race.id)) ?? []
            let resultsVM = ResultsViewModel(race: race, athletes: athletes, splits: splits, meet: vm.meet)
            ResultsView(vm: resultsVM)
        }
    }

    private func raceGenderBar(_ race: Race) -> some View {
        let genders = race.athleteIds.compactMap { id in
            vm.athletes.first(where: { $0.id == id })?.gender
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

    private func statusBadge(_ status: RaceStatus) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.statusColor(status).opacity(0.15))
            .foregroundStyle(Theme.statusColor(status))
            .clipShape(Capsule())
    }
}
