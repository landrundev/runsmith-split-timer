import SwiftUI

struct RaceHistoryView: View {
    @ObservedObject var vm: HomeViewModel
    let cache: RaceStateCache
    @EnvironmentObject var store: SplitDeckStore

    @State private var raceToDelete: Race? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    /// Races grouped by date (day), newest first.
    private var groupedRaces: [(key: String, races: [Race])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: vm.startedQuickRaces) { race -> String in
            let date = race.startedAt ?? race.endedAt ?? Date()
            let day = calendar.startOfDay(for: date)
            return Self.sectionDateFormatter.string(from: day)
        }
        // Sort sections by actual date descending
        return grouped
            .map { (key: $0.key, races: $0.value) }
            .sorted { lhs, rhs in
                let lDate = lhs.races.first?.startedAt ?? .distantPast
                let rDate = rhs.races.first?.startedAt ?? .distantPast
                return lDate > rDate
            }
    }

    var body: some View {
        List {
            ForEach(groupedRaces, id: \.key) { section in
                Section {
                    ForEach(section.races) { race in
                        NavigationLink(destination: raceDestination(race)) {
                            RaceCardRow(
                                race: race,
                                athletes: vm.athletes,
                                dateFormatter: Self.dateFormatter
                            )
                        }
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
                            .tint(.blue)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    Text(section.key)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.screenBackground)
        .navigationTitle("Race History")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete \"\(raceToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { raceToDelete != nil },
                set: { if !$0 { raceToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: raceToDelete
        ) { race in
            Button("Delete Race", role: .destructive) {
                vm.delete(race: race)
                raceToDelete = nil
            }
            Button("Cancel", role: .cancel) { raceToDelete = nil }
        }
    }

    // MARK: \u{2013} Navigation Destinations

    @ViewBuilder
    private func raceDestination(_ race: Race) -> some View {
        Group {
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
        .hidesTabBar()
    }
}
