import SwiftUI

struct MeetDetailView: View {
    @ObservedObject var vm: MeetDetailViewModel
    let store: SplitDeckStore
    let cache: RaceStateCache

    @State private var showAddRace = false
    @State private var raceToDelete: Race? = nil

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
                ForEach(vm.races) { race in
                    raceRow(race)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                raceToDelete = race
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(race.name)
                        .font(.headline)
                    Text(race.eventType.displayName)
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
            let setupVM = RaceSetupViewModel(meetId: vm.meet.id, store: store)
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
