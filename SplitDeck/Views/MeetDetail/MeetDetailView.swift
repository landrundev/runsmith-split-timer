import SwiftUI

struct MeetDetailView: View {
    @ObservedObject var vm: MeetDetailViewModel
    let store: SplitDeckStore
    let cache: RaceStateCache

    @State private var showAddRace = false
    @State private var showShareMeet = false
    @State private var showImportRace = false
    @State private var raceToDelete: Race? = nil
    @State private var genderFilter: Gender? = nil
    @State private var pendingRaceToSetup: Race? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var filteredRaces: [Race] {
        guard let gender = genderFilter else { return vm.races }
        return vm.races.filter { race in
            let genders = race.athleteIds.compactMap { id in
                vm.athletes.first(where: { $0.id == id })?.gender
            }
            return genders.contains(gender)
        }
    }

    private var completedCount: Int {
        vm.races.filter { $0.status == .completed }.count
    }

    private var inProgressCount: Int {
        vm.races.filter { $0.status == .inProgress }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Meet info header card
                meetInfoCard

                if vm.races.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.textMuted)
                        Text("No Races")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Tap + Add Race to create one.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Gender filter pills
                    genderFilterRow
                        .padding(.horizontal, 16)

                    // Race cards
                    VStack(spacing: 8) {
                        ForEach(filteredRaces) { race in
                            raceCardButton(race)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        raceToDelete = race
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
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Theme.screenBackground)
        .navigationTitle(vm.meet.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showAddRace = true
                    } label: {
                        Label("Add Race", systemImage: "plus")
                    }

                    Button {
                        showImportRace = true
                    } label: {
                        Label("Import Race", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showShareMeet = true
                    } label: {
                        Label("Share Meet Config", systemImage: "person.2.wave.2")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareMeet) {
            ShareMeetConfigView(config: vm.buildSharedMeetConfig())
        }
        .sheet(isPresented: $showImportRace, onDismiss: { vm.load() }) {
            ImportRaceView(store: store)
        }
        .sheet(isPresented: $showAddRace, onDismiss: { vm.load() }) {
            RaceSetupView(
                vm: RaceSetupViewModel(meetId: vm.meet.id, store: store),
                store: store,
                cache: cache
            )
        }
        .sheet(item: $pendingRaceToSetup, onDismiss: { vm.load() }) { race in
            RaceSetupView(
                vm: RaceSetupViewModel(meetId: vm.meet.id, store: store, existingRaceId: race.id),
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

    // MARK: – Meet Info Header Card

    private var meetInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date + Location
            HStack(spacing: 12) {
                Label(Self.dateFormatter.string(from: vm.meet.date), systemImage: "calendar")
                if let loc = vm.meet.location {
                    Label(loc, systemImage: "mappin")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)

            // Stats row
            HStack(spacing: 16) {
                statPill(icon: "stopwatch", value: "\(vm.races.count)", label: "Total")
                if completedCount > 0 {
                    statPill(icon: "checkmark.circle", value: "\(completedCount)", label: "Done", color: .green)
                }
                if inProgressCount > 0 {
                    statPill(icon: "play.circle", value: "\(inProgressCount)", label: "Live", color: .orange)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .padding(.horizontal, 16)
    }

    private func statPill(icon: String, value: String, label: String, color: Color = Theme.textPrimary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: – Gender Filter

    private var genderFilterRow: some View {
        HStack(spacing: 8) {
            Text("Filter")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            genderFilterButton("All", gender: nil)
            genderFilterButton("M", gender: .male)
            genderFilterButton("F", gender: .female)
        }
    }

    private func genderFilterButton(_ label: String, gender: Gender?) -> some View {
        let isActive = genderFilter == gender
        let tintColor: Color = {
            if !isActive { return Theme.textTertiary }
            if let g = gender { return Theme.genderTint(g) }
            return Theme.accentPrimary
        }()

        return Button(label) {
            genderFilter = genderFilter == gender ? nil : gender
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? tintColor.opacity(0.15) : Theme.cardBackground)
        .foregroundStyle(isActive ? tintColor : Theme.textSecondary)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(isActive ? tintColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: – Race Card Button

    @ViewBuilder
    private func raceCardButton(_ race: Race) -> some View {
        if race.status == .notStarted {
            Button { pendingRaceToSetup = race } label: {
                MeetRaceCardRow(
                    race: race,
                    athletes: vm.athletes,
                    bestTime: vm.bestTimeDisplay(for: race)
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: raceDestination(race)) {
                MeetRaceCardRow(
                    race: race,
                    athletes: vm.athletes,
                    bestTime: vm.bestTimeDisplay(for: race)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – Navigation Destinations

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
}
