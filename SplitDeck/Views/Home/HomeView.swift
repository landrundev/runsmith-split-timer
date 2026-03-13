import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting
    @Binding var selectedTab: MainTabView.Tab
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWideLayout: Bool { sizeClass == .regular }

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

    /// Show at most 10 quick race history items on Home.
    private static let homeHistoryLimit = 10

    var body: some View {
        NavigationStack {
            List {
                heroSection
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                pendingRacesSection

                quickRaceHistorySection

                emptyState

                // Bottom spacer so content clears the custom tab bar
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
            .adaptiveSheet(item: $pendingRaceToSetup, onDismiss: { vm.load() }) { race in
                RaceSetupView(
                    vm: RaceSetupViewModel(meetId: nil, store: store, existingRaceId: race.id),
                    store: store,
                    cache: cache
                )
            }
            .adaptiveSheet(isPresented: $showMeetRaceSetup, onDismiss: { vm.load() }) {
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

            NavigationLink(destination: meetDestination(meet)) {
                HeroMeetCard(
                    meet: meet,
                    status: vm.meetStatus(for: meet),
                    completedCount: vm.completedRaceCount(for: meet),
                    totalCount: vm.totalRaceCount(for: meet),
                    hasInProgressRace: inProgressRace != nil
                )
                .overlay(alignment: .bottom) {
                    Button {
                        handleHeroCTA(
                            meet: meet,
                            inProgressRace: inProgressRace,
                            nextRace: nextRace,
                            allDone: allDone
                        )
                    } label: {
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
            Button {
                selectedTab = .meets
            } label: {
                NoMeetCard()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private func handleHeroCTA(meet: Meet, inProgressRace: Race?, nextRace: Race?, allDone: Bool) {
        if let race = inProgressRace {
            ctaLiveRace = race
        } else if allDone {
            // card tap handles navigation to MeetDetail
        } else if let race = nextRace {
            meetRaceSetupVM = RaceSetupViewModel(
                meetId: meet.id, store: store, existingRaceId: race.id
            )
            showMeetRaceSetup = true
        }
    }

    // MARK: \u{2013} Pending Races

    @ViewBuilder
    private var pendingRacesSection: some View {
        if !vm.pendingQuickRaces.isEmpty {
            Section {
                if isWideLayout {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(vm.pendingQuickRaces) { race in
                            Button { pendingRaceToSetup = race } label: {
                                RaceCardRow(
                                    race: race,
                                    athletes: vm.athletes,
                                    dateFormatter: Self.dateFormatter
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else {
                    ForEach(vm.pendingQuickRaces) { race in
                        Button { pendingRaceToSetup = race } label: {
                            RaceCardRow(
                                race: race,
                                athletes: vm.athletes,
                                dateFormatter: Self.dateFormatter
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                quickRaceToDelete = race
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
                            .tint(.blue)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onMove(perform: vm.movePendingRace)
                }
            } header: {
                Text("Pending Races")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: \u{2013} Quick Race History (capped at 10)

    @ViewBuilder
    private var quickRaceHistorySection: some View {
        let allHistory = vm.startedQuickRaces
        if !allHistory.isEmpty {
            Section {
                if isWideLayout {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(allHistory.prefix(Self.homeHistoryLimit)) { race in
                            NavigationLink(destination: quickRaceDestination(race)) {
                                RaceCardRow(
                                    race: race,
                                    athletes: vm.athletes,
                                    dateFormatter: Self.dateFormatter
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else {
                    ForEach(allHistory.prefix(Self.homeHistoryLimit)) { race in
                        NavigationLink(destination: quickRaceDestination(race)) {
                            RaceCardRow(
                                race: race,
                                athletes: vm.athletes,
                                dateFormatter: Self.dateFormatter
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                quickRaceToDelete = race
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
                            .tint(.blue)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                // "See All" link when more than 10
                if vm.hasMoreHistory {
                    NavigationLink {
                        RaceHistoryView(vm: vm, cache: cache)
                    } label: {
                        HStack {
                            Text("See All Races")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(allHistory.count)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .foregroundStyle(Theme.accentPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } header: {
                Text("Quick Race History")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: \u{2013} Empty State

    @ViewBuilder
    private var emptyState: some View {
        if vm.quickRaces.isEmpty && vm.nextMeet == nil {
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
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
}
