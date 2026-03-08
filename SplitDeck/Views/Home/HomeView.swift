import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting
    @Binding var selectedTab: Int  // tab bar index, so we can switch to Meets

    // Delete confirmation
    @State private var quickRaceToDelete: Race? = nil

    // Pending race setup (sheet-based to avoid nested NavigationStack)
    @State private var pendingRaceToSetup: Race? = nil

    // Meet CTA navigation
    @State private var showMeetRaceSetup = false
    @State private var meetRaceSetupVM: RaceSetupViewModel? = nil
    @State private var ctaLiveRace: Race? = nil  // drives fullScreenCover for resume

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroSection
                    recentResultsSection
                    pendingRacesSection
                    quickRaceHistorySection
                    emptyState
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
            .sheet(isPresented: $showMeetRaceSetup, onDismiss: { vm.load() }) {
                if let setupVM = meetRaceSetupVM {
                    RaceSetupView(vm: setupVM, store: store, cache: cache)
                }
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
            .fullScreenCover(item: $ctaLiveRace, onDismiss: { vm.load() }) { race in
                NavigationStack {
                    let athletes = (try? store.fetchAthletes()) ?? []
                    let ltVM = LiveTimingViewModel(
                        race: race, athletes: athletes, store: store, cache: cache
                    )
                    LiveTimingView(vm: ltVM, cache: cache)
                }
            }
            .onAppear { vm.load() }
        }
    }

    // MARK: \u{2013} Hero Section

    @ViewBuilder
    private var heroSection: some View {
        if let meet = vm.nextMeet {
            let inProgressRace = vm.inProgressRace(for: meet)
            let nextRace = vm.nextUnstartedRace(for: meet)
            let allDone = vm.completedRaceCount(for: meet) >= vm.totalRaceCount(for: meet)
                && vm.totalRaceCount(for: meet) > 0

            // Tapping the card body \u{2013} MeetDetailView
            NavigationLink(destination: meetDestination(meet)) {
                HeroMeetCard(
                    meet: meet,
                    status: vm.meetStatus(for: meet),
                    completedCount: vm.completedRaceCount(for: meet),
                    totalCount: vm.totalRaceCount(for: meet),
                    hasInProgressRace: inProgressRace != nil
                )
                // Overlay the CTA as a separate tap target
                .overlay(alignment: .bottom) {
                    Button {
                        handleHeroCTA(
                            meet: meet,
                            inProgressRace: inProgressRace,
                            nextRace: nextRace,
                            allDone: allDone
                        )
                    } label: {
                        // Invisible tap target covering the CTA area
                        Color.clear
                            .frame(height: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else {
            // No upcoming meet placeholder
            Button {
                selectedTab = 1  // Switch to Meets tab
            } label: {
                NoMeetCard()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private func handleHeroCTA(meet: Meet, inProgressRace: Race?, nextRace: Race?, allDone: Bool) {
        if let race = inProgressRace {
            // Resume in-progress race \u{2013} push LiveTimingView
            ctaLiveRace = race
        } else if allDone {
            // All done \u{2013} card tap handles navigation to MeetDetail
        } else if let race = nextRace {
            // Start next race \u{2013} sheet RaceSetupView
            meetRaceSetupVM = RaceSetupViewModel(
                meetId: meet.id, store: store, existingRaceId: race.id
            )
            showMeetRaceSetup = true
        }
    }

    // MARK: \u{2013} Recent Results

    @ViewBuilder
    private var recentResultsSection: some View {
        if !vm.recentResults.isEmpty {
            sectionView(title: "Recent Results") {
                ForEach(vm.recentResults) { result in
                    NavigationLink(destination: resultDestination(result)) {
                        RecentResultRow(result: result, athletes: vm.athletes)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: \u{2013} Pending Races

    @ViewBuilder
    private var pendingRacesSection: some View {
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
    }

    // MARK: \u{2013} Quick Race History

    @ViewBuilder
    private var quickRaceHistorySection: some View {
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
    }

    // MARK: \u{2013} Empty State

    @ViewBuilder
    private var emptyState: some View {
        if vm.quickRaces.isEmpty && vm.nextMeet == nil && vm.recentResults.isEmpty {
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

    // MARK: \u{2013} Section Builder

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

    // MARK: \u{2013} Navigation Destinations

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

    @ViewBuilder
    private func resultDestination(_ result: HomeViewModel.RecentResult) -> some View {
        // Fetch fresh data for this race
        let allRaces: [Race] = {
            if let mid = result.meetId {
                return (try? store.fetchRaces(for: mid)) ?? []
            } else {
                return (try? store.fetchRaces(for: nil)) ?? []
            }
        }()

        if let race = allRaces.first(where: { $0.id == result.id }) {
            let athletes = (try? store.fetchAthletes()) ?? []
            let splits   = (try? store.fetchSplits(for: race.id)) ?? []
            let meet: Meet? = {
                guard let mid = result.meetId else { return nil }
                return vm.meets.first(where: { $0.id == mid })
            }()
            ResultsView(
                vm: ResultsViewModel(race: race, athletes: athletes, splits: splits, meet: meet)
            )
        }
    }
}
