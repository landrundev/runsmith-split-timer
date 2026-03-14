import SwiftUI

struct SpectatorHomeView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var selectedChild: AppSettings.SpectatorChild? = nil
    @State private var navigateToDetail = false
    @State private var showAddAthlete = false
    @State private var showTimeRace = false
    @State private var showSettings = false
    @State private var myChildren: [AppSettings.SpectatorChild] = AppSettings.myChildren
    @State private var pendingRaces: [Race] = []
    @State private var selectedPendingRace: Race? = nil
    @State private var navigateToStaging = false
    @State private var navigateToLiveTiming = false
    @State private var liveTimingVM: LiveTimingViewModel? = nil
    @State private var quickTemplates: [AppSettings.QuickRaceTemplate] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MY ATHLETES
                sectionHeader("MY ATHLETES")

                if myChildren.isEmpty {
                    emptyAthleteCard
                } else {
                    VStack(spacing: 8) {
                        ForEach(myChildren) { child in
                            Button {
                                selectedChild = child
                                navigateToDetail = true
                            } label: {
                                SpectatorChildRowView(child: child, store: store)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("+ Add another athlete") {
                            showAddAthlete = true
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.runsmithPink)
                        .padding(.top, 4)
                    }
                }

                // PENDING RACES
                if !pendingRaces.isEmpty {
                    Spacer(minLength: 24)
                    sectionHeader("SAVED RACES")

                    VStack(spacing: 8) {
                        ForEach(pendingRaces) { race in
                            Button {
                                if race.status == .inProgress {
                                    resumeRace(race)
                                } else {
                                    selectedPendingRace = race
                                    navigateToStaging = true
                                }
                            } label: {
                                pendingRaceRow(race)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 24)

                // TIME A RACE
                sectionHeader("TIME A RACE")

                Button {
                    showTimeRace = true
                } label: {
                    Label("Time a Race Now", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.markButtonHeight)
                }
                .buttonStyle(GlassPrimaryButtonStyle(color: .green))
                .disabled(myChildren.isEmpty)

                if myChildren.isEmpty {
                    Text("Add an athlete above first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // QUICK START
                if !quickTemplates.isEmpty && !myChildren.isEmpty {
                    Spacer(minLength: 12)
                    sectionHeader("QUICK START")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickTemplates) { template in
                                Button {
                                    quickStartFromTemplate(template)
                                } label: {
                                    Text(template.label)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Theme.cardBackground)
                                        .clipShape(Capsule())
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Runsmith")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("RunsmithLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .navigationDestination(isPresented: $navigateToDetail) {
            if let child = selectedChild {
                SpectatorAthleteDetailView(child: child, store: store)
            }
        }
        .navigationDestination(isPresented: $navigateToStaging) {
            if let race = selectedPendingRace {
                SpectatorStagingView(race: race, store: store, cache: cache) {
                    refreshAll()
                }
            }
        }
        .navigationDestination(isPresented: $navigateToLiveTiming) {
            if let vm = liveTimingVM {
                LiveTimingView(vm: vm, cache: cache, onRaceComplete: {
                    refreshAll()
                })
                .hidesTabBar()
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: refreshAll) {
            SpectatorSettingsView()
        }
        .sheet(isPresented: $showAddAthlete, onDismiss: refreshAll) {
            SpectatorSetupView(mode: .addAthlete)
        }
        .sheet(isPresented: $showTimeRace, onDismiss: refreshAll) {
            SpectatorSetupView(mode: .startRace)
        }
        .onAppear { refreshAll() }
    }

    // MARK: - Helpers

    private func refreshAll() {
        myChildren = AppSettings.myChildren
        loadPendingRaces()
        quickTemplates = AppSettings.quickRaceTemplates
    }

    private func loadPendingRaces() {
        let childIds = Set(myChildren.map(\.id))
        guard !childIds.isEmpty else { pendingRaces = []; return }
        var seen = Set<UUID>()
        var result: [Race] = []
        for childId in childIds {
            guard let races = try? store.fetchRaces(forAthlete: childId) else { continue }
            for race in races where (race.status == .notStarted || race.status == .inProgress) && !seen.contains(race.id) {
                seen.insert(race.id)
                result.append(race)
            }
        }
        pendingRaces = result.sorted { ($0.startedAt ?? $0.endedAt ?? .distantPast) > ($1.startedAt ?? $1.endedAt ?? .distantPast) }
    }

    private func resumeRace(_ race: Race) {
        let allAthletes = (try? store.fetchAthletes()) ?? []
        liveTimingVM = LiveTimingViewModel(race: race, athletes: allAthletes, store: store, cache: cache)
        navigateToLiveTiming = true
    }

    private func quickStartFromTemplate(_ template: AppSettings.QuickRaceTemplate) {
        guard let eventType = EventType(rawValue: template.eventTypeRaw) else { return }
        let athleteIds = template.isRelay ? template.relayAthleteIds : [template.athleteId]
        let race = Race(
            name: template.label,
            eventType: eventType,
            distanceMeters: eventType.defaultDistance ?? 0,
            trackLengthMeters: eventType.isRelay ? (eventType.legDistanceMeters ?? 400) : 400,
            splitsPerLap: 1,
            athleteIds: athleteIds,
            status: .notStarted
        )
        try? store.save(race)
        selectedPendingRace = race
        navigateToStaging = true
    }

    private var emptyAthleteCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Add your athlete to get started")
                .font(.subheadline)
            Button("+ Add Athlete") {
                showAddAthlete = true
            }
            .foregroundStyle(Theme.runsmithPink)
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func pendingRaceRow(_ race: Race) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(race.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(race.eventType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if race.status == .inProgress {
                Text("In Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Not Started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - SpectatorChildRowView

struct SpectatorChildRowView: View {
    let child: AppSettings.SpectatorChild
    let store: SplitDeckStore

    @State private var lastRaceSummary: String = "No races yet"
    @State private var athleteColor: String = "#888888"

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: athleteColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(child.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(lastRaceSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .onAppear { loadSummary() }
    }

    private func loadSummary() {
        // Resolve athlete color
        if let athletes = try? store.fetchAthletes(),
           let athlete = athletes.first(where: { $0.id == child.id }) {
            athleteColor = athlete.colorHex
        }

        // Find last completed race
        guard let races = try? store.fetchRaces(forAthlete: child.id) else { return }
        let completed = races
            .filter { $0.status == .completed }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        guard let lastRace = completed.first else { return }

        guard let splits = try? store.fetchSplits(for: lastRace.id),
              let athletes = try? store.fetchAthletes(),
              let athlete = athletes.first(where: { $0.id == child.id }),
              let finalMs = RaceDomain.finalTime(athlete: athlete, splits: splits, race: lastRace)
        else { return }

        var summary = "\(lastRace.eventType.displayName) \u{00B7} \(finalMs.formattedSplitTime)"

        // PR check: is this the best time for this event?
        let sameEvent = completed.filter { $0.eventType == lastRace.eventType && $0.id != lastRace.id }
        let priorBest = sameEvent.compactMap { race -> Int? in
            guard let s = try? store.fetchSplits(for: race.id) else { return nil }
            return RaceDomain.finalTime(athlete: athlete, splits: s, race: race)
        }.min()

        if priorBest == nil || finalMs <= (priorBest ?? Int.max) {
            summary += " \u{2193} PR"
        }

        lastRaceSummary = summary
    }
}
