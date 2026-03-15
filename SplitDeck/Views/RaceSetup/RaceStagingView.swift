import SwiftUI

private struct AthleteQuickStats {
    let athlete: Athlete
    let prMs: Int?
    let lastRaceMs: Int?
    let racesInEvent: Int
}

struct RaceStagingView: View {
    let race: Race
    let athletes: [Athlete]
    @ObservedObject var vm: RaceSetupViewModel
    let store: SplitDeckStore
    let cache: RaceStateCache
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showShareConfig = false
    @State private var navigateToLiveTiming = false
    @State private var liveTimingVM: LiveTimingViewModel?
    @State private var athleteQuickStats: [AthleteQuickStats] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Race summary card
                raceSummaryCard

                // Athletes
                athleteSection

                // Multi-coach sharing
                if !race.eventType.isRelay || race.splitsPerLap == 1 {
                    multiCoachSection
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .safeAreaInset(edge: .bottom) {
            startTimingButton
        }
        .navigationTitle(race.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Edit Setup")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareConfig) {
            ShareRaceConfigView(config: vm.buildSharedConfig())
        }
        .navigationDestination(isPresented: $navigateToLiveTiming) {
            if let liveVM = liveTimingVM {
                LiveTimingView(vm: liveVM, cache: cache, onRaceComplete: onDone)
                    .hidesTabBar()
            }
        }
        .hidesTabBar()
        .onAppear { loadAthleteStats() }
    }

    // MARK: – Race Summary Card

    private var raceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(race.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 4) {
                Text(race.eventType.displayName)
                if let lapText = race.lapDisplayString {
                    Text("\u{00B7}")
                    Text(lapText)
                    if race.splitsPerLap > 1 {
                        Text("\u{00B7}")
                        Text("\(race.splitsPerLap) splits/lap")
                    }
                } else if race.isUnlimitedSplits {
                    Text("\u{00B7}")
                    Text("Unlimited splits")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)

            Text(verbatim: "\(race.trackLengthMeters)m track")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: – Athletes

    private var athleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(athletes.count) Athlete\(athletes.count == 1 ? "" : "s")")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            if race.eventType.isRelay {
                relayLegList
            } else {
                athleteRows
            }
        }
    }

    private var athleteRows: some View {
        VStack(spacing: 8) {
            ForEach(athleteQuickStats, id: \.athlete.id) { stats in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: stats.athlete.colorHex))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stats.athlete.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        if stats.racesInEvent > 0 {
                            HStack(spacing: 4) {
                                if let pr = stats.prMs {
                                    Text("PR: \(pr.formattedSplitTime)")
                                }
                                if let last = stats.lastRaceMs, last != stats.prMs {
                                    Text("\u{00B7}")
                                    Text("Last: \(last.formattedSplitTime)")
                                }
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("First \(race.eventType.displayName)!")
                                .font(.caption)
                                .foregroundStyle(Theme.badgeYellow)
                        }
                    }

                    Spacer()
                }
                .padding(14)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            }
        }
    }

    private var relayLegList: some View {
        VStack(spacing: 0) {
            ForEach(Array(athletes.enumerated()), id: \.element.id) { i, athlete in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24)

                    Rectangle()
                        .fill(Color(hex: athlete.colorHex))
                        .frame(width: Theme.colorBarWidth)
                        .clipShape(Capsule())

                    Text(athlete.name)
                        .font(.body.weight(.medium))

                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                if i < athletes.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: – Multi-Coach

    private var multiCoachSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timing with another coach?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)

            Button {
                vm.ensureConfigId()
                showShareConfig = true
            } label: {
                Label("Share Race Config", systemImage: "person.2.wave.2")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Theme.runsmithPink)
        }
    }

    // MARK: – Stats Loading

    private func loadAthleteStats() {
        guard !race.eventType.isRelay else { return }
        athleteQuickStats = athletes.map { athlete in
            let allRaces = (try? store.fetchRaces(forAthlete: athlete.id)) ?? []
            let eventRaces = allRaces
                .filter { $0.status == .completed && $0.eventType == race.eventType }
                .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }

            var prMs: Int?
            var lastMs: Int?

            for (i, pastRace) in eventRaces.enumerated() {
                guard let splits = try? store.fetchSplits(for: pastRace.id),
                      let finalMs = RaceDomain.finalTime(athlete: athlete, splits: splits, race: pastRace)
                else { continue }
                if i == 0 { lastMs = finalMs }
                if prMs == nil || finalMs < prMs! { prMs = finalMs }
            }

            return AthleteQuickStats(
                athlete: athlete,
                prMs: prMs,
                lastRaceMs: lastMs,
                racesInEvent: eventRaces.count
            )
        }
    }

    // MARK: – Start Timing

    private var startTimingButton: some View {
        Button {
            guard let startedRace = vm.beginRace(existingRaceId: race.id) else { return }
            let allAthletes = (try? store.fetchAthletes()) ?? []
            liveTimingVM = LiveTimingViewModel(
                race: startedRace, athletes: allAthletes, store: store, cache: cache
            )
            navigateToLiveTiming = true
        } label: {
            Text("START TIMING")
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.markButtonHeight)
        }
        .buttonStyle(GlassPrimaryButtonStyle(color: .green))
        .glassActionBar()
    }
}
