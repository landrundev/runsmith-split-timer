import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting

    // Delete confirmation
    @State private var quickRaceToDelete: Race? = nil

    // Pending race setup (sheet-based to avoid nested NavigationStack)
    @State private var pendingRaceToSetup: Race? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var pendingQuickRaces: [Race] {
        vm.quickRaces.filter { $0.status == .notStarted }
    }

    private var startedQuickRaces: [Race] {
        vm.quickRaces.filter { $0.status != .notStarted }
    }

    /// The nearest future (or today) non-archived meet, sorted by date.
    private var nextMeet: Meet? {
        let today = Calendar.current.startOfDay(for: Date())
        return vm.meets
            .filter { !$0.isArchived && Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero meet card
                    if let meet = nextMeet {
                        NavigationLink(destination: meetDestination(meet)) {
                            HeroMeetCard(
                                meet: meet,
                                raceCount: vm.meetRaces[meet.id]?.count ?? 0,
                                status: vm.meetStatus(for: meet)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    // Pending quick races
                    if !pendingQuickRaces.isEmpty {
                        sectionView(title: "Pending Races") {
                            ForEach(pendingQuickRaces) { race in
                                Button { pendingRaceToSetup = race } label: {
                                    RaceCardRow(
                                        race: race,
                                        athletes: vm.athletes,
                                        dateFormatter: Self.dateFormatter
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        quickRaceToDelete = race
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        vm.archive(race: race)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                            }
                        }
                    }

                    // Quick Race History
                    if !startedQuickRaces.isEmpty {
                        sectionView(title: "Quick Race History") {
                            ForEach(startedQuickRaces) { race in
                                NavigationLink(destination: quickRaceDestination(race)) {
                                    RaceCardRow(
                                        race: race,
                                        athletes: vm.athletes,
                                        dateFormatter: Self.dateFormatter
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        quickRaceToDelete = race
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        vm.archive(race: race)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    if vm.quickRaces.isEmpty && nextMeet == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textMuted)
                            Text("No Races Yet")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Tap + to start a quick race.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Runsmith")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView(appearance: $appearance)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Image("RunsmithLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
            .sheet(item: $pendingRaceToSetup, onDismiss: { vm.load() }) { race in
                RaceSetupView(
                    vm: RaceSetupViewModel(meetId: nil, store: store, existingRaceId: race.id),
                    store: store,
                    cache: cache
                )
            }
            .confirmationDialog(
                "Delete \"\(quickRaceToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { quickRaceToDelete != nil },
                    set: { if !$0 { quickRaceToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: quickRaceToDelete
            ) { race in
                Button("Delete Race", role: .destructive) {
                    vm.delete(race: race)
                    quickRaceToDelete = nil
                }
                Button("Cancel", role: .cancel) { quickRaceToDelete = nil }
            }
            .onAppear { vm.load() }
        }
    }

    // MARK: – Section Builder

    @ViewBuilder
    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: – Navigation Destinations

    @ViewBuilder
    private func meetDestination(_ meet: Meet) -> some View {
        MeetDetailView(
            vm: MeetDetailViewModel(meet: meet, store: store),
            store: store,
            cache: cache
        )
    }

    @ViewBuilder
    private func quickRaceDestination(_ race: Race) -> some View {
        switch race.status {
        case .completed:
            let athletes = (try? store.fetchAthletes()) ?? []
            let splits   = (try? store.fetchSplits(for: race.id)) ?? []
            ResultsView(
                vm: ResultsViewModel(race: race, athletes: athletes, splits: splits, meet: nil)
            )

        case .inProgress:
            let athletes = (try? store.fetchAthletes()) ?? []
            let liveVM = LiveTimingViewModel(
                race: race, athletes: athletes, store: store, cache: cache
            )
            LiveTimingView(vm: liveVM, cache: cache)

        case .notStarted:
            let setupVM = RaceSetupViewModel(meetId: nil, store: store, existingRaceId: race.id)
            RaceSetupView(vm: setupVM, store: store, cache: cache)
        }
    }
}
