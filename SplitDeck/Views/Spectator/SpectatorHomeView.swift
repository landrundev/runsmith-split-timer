import SwiftUI

struct SpectatorHomeView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var selectedChild: AppSettings.SpectatorChild? = nil
    @State private var navigateToDetail = false
    @State private var showAddAthlete = false
    @State private var showTimeRace = false
    @State private var showSettings = false

    private var myChildren: [AppSettings.SpectatorChild] {
        AppSettings.myChildren
    }

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
        .sheet(isPresented: $showSettings) {
            SpectatorSettingsView()
        }
        .sheet(isPresented: $showAddAthlete) {
            SpectatorSetupView(mode: .addAthlete)
        }
        .sheet(isPresented: $showTimeRace) {
            SpectatorSetupView(mode: .startRace)
        }
    }

    // MARK: - Helpers

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
