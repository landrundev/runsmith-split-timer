import SwiftUI

struct SpectatorAthleteDetailView: View {
    let child: AppSettings.SpectatorChild
    let store: SplitDeckStore

    @State private var personalBests: [(eventType: EventType, bestMs: Int, date: Date)] = []
    @State private var recentRaces: [(race: Race, finalMs: Int?, isPR: Bool)] = []
    @State private var editName: String = ""
    @State private var showEditName = false
    @State private var selectedRace: Race? = nil
    @State private var navigateToResults = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // PERSONAL BESTS
                sectionHeader("PERSONAL BESTS")

                if personalBests.isEmpty {
                    Text("No completed races yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(personalBests.enumerated()), id: \.offset) { _, pb in
                            HStack {
                                Text(pb.eventType.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .frame(width: 80, alignment: .leading)
                                Text(pb.bestMs.formattedSplitTime)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                Spacer()
                                Text(pb.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                        }
                    }
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                }

                // RECENT RACES
                sectionHeader("RECENT RACES")

                if recentRaces.isEmpty {
                    Text("No races yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(recentRaces.enumerated()), id: \.offset) { _, entry in
                            SwipeDeleteRow(
                                onTap: {
                                    selectedRace = entry.race
                                    navigateToResults = true
                                },
                                onDelete: { deleteRace(entry.race) }
                            ) {
                                raceRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle(child.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    editName = child.displayName
                    showEditName = true
                }
            }
        }
        .alert("Rename Athlete", isPresented: $showEditName) {
            TextField("Display name", text: $editName)
            Button("Save") {
                guard !editName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                var updated = child
                updated.displayName = editName.trimmingCharacters(in: .whitespaces)
                AppSettings.updateChild(updated)
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let race = selectedRace {
                resultsView(for: race)
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Helpers

    private func deleteRace(_ race: Race) {
        try? store.delete(raceId: race.id)
        loadData()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func raceRow(_ entry: (race: Race, finalMs: Int?, isPR: Bool)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.race.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let date = entry.race.startedAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let ms = entry.finalMs {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ms.formattedSplitTime)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                    if entry.isPR {
                        Text("PR")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
            } else {
                Text("Incomplete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    @ViewBuilder
    private func resultsView(for race: Race) -> some View {
        let athletes = (try? store.fetchAthletes()) ?? []
        let splits = (try? store.fetchSplits(for: race.id)) ?? []
        ResultsView(vm: ResultsViewModel(race: race, athletes: athletes, splits: splits, meet: nil))
    }

    private func loadData() {
        guard let allAthletes = try? store.fetchAthletes(),
              let athlete = allAthletes.first(where: { $0.id == child.id }),
              let races = try? store.fetchRaces(forAthlete: child.id)
        else { return }

        let completedRaces = races
            .filter { $0.status == .completed }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }

        // Compute PBs grouped by event type
        var bestByEvent: [EventType: (ms: Int, date: Date)] = [:]
        for race in completedRaces {
            guard let splits = try? store.fetchSplits(for: race.id),
                  let ms = RaceDomain.finalTime(athlete: athlete, splits: splits, race: race)
            else { continue }

            let date = race.startedAt ?? race.endedAt ?? Date()
            if let existing = bestByEvent[race.eventType] {
                if ms < existing.ms {
                    bestByEvent[race.eventType] = (ms, date)
                }
            } else {
                bestByEvent[race.eventType] = (ms, date)
            }
        }

        personalBests = bestByEvent
            .map { (eventType: $0.key, bestMs: $0.value.ms, date: $0.value.date) }
            .sorted { ($0.eventType.defaultDistance ?? 0) < ($1.eventType.defaultDistance ?? 0) }

        // Compute recent races — mark only current PB as PR
        var raceEntries: [(race: Race, finalMs: Int?, isPR: Bool)] = []

        for race in completedRaces {
            guard let splits = try? store.fetchSplits(for: race.id) else {
                raceEntries.append((race: race, finalMs: nil, isPR: false))
                continue
            }
            let ms = RaceDomain.finalTime(athlete: athlete, splits: splits, race: race)
            let isPR: Bool
            if let ms = ms, let best = bestByEvent[race.eventType] {
                isPR = ms <= best.ms
            } else {
                isPR = false
            }
            raceEntries.append((race: race, finalMs: ms, isPR: isPR))
        }

        // Already sorted most-recent first
        recentRaces = raceEntries

        // Also include incomplete races
        let incompleteRaces = races
            .filter { $0.status != .completed }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            .map { (race: $0, finalMs: nil as Int?, isPR: false) }

        recentRaces = recentRaces + incompleteRaces
    }
}
