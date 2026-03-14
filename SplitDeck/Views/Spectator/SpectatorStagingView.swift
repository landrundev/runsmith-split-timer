import SwiftUI

struct SpectatorStagingView: View {
    let race: Race
    let store: SplitDeckStore
    let cache: RaceStateCache
    let onDone: () -> Void

    @State private var navigateToLiveTiming = false
    @State private var liveTimingVM: LiveTimingViewModel?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Race summary card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(race.name)
                            .font(.headline)
                        HStack {
                            Text(race.eventType.displayName)
                            Text("\u{00B7}")
                            if race.isUnlimitedSplits {
                                Text("Unlimited")
                            } else {
                                Text("\(race.distanceMeters)m \u{00B7} \(race.laps) laps")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)

                        Text("\(race.trackLengthMeters)m track")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

                    // Athletes
                    if race.eventType.isRelay {
                        relayLegList
                    } else {
                        athleteChips
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle(race.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                startTiming()
            } label: {
                Text("START TIMING")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.markButtonHeight)
            }
            .buttonStyle(GlassPrimaryButtonStyle(color: .green))
            .glassActionBar()
        }
        .navigationDestination(isPresented: $navigateToLiveTiming) {
            if let vm = liveTimingVM {
                LiveTimingView(vm: vm, cache: cache, onRaceComplete: onDone)
                    .hidesTabBar()
            }
        }
    }

    // MARK: - Subviews

    private var athleteChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(race.athleteIds.count) Athlete\(race.athleteIds.count == 1 ? "" : "s")")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            let athletes = resolvedAthletes
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(athletes) { athlete in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 10, height: 10)
                        Text(athlete.name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.cardBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var relayLegList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relay Legs")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            let athletes = resolvedAthletes
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
                }
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }

    // MARK: - Helpers

    private var resolvedAthletes: [Athlete] {
        let allAthletes = (try? store.fetchAthletes()) ?? []
        return race.athleteIds.compactMap { id in allAthletes.first { $0.id == id } }
    }

    private func startTiming() {
        var updated = race
        updated = Race(
            id: race.id, meetId: race.meetId, configId: race.configId,
            name: race.name, eventType: race.eventType,
            distanceMeters: race.distanceMeters,
            trackLengthMeters: race.trackLengthMeters,
            splitsPerLap: race.splitsPerLap,
            isUnlimitedSplits: race.isUnlimitedSplits,
            athleteIds: race.athleteIds,
            startedAt: Date(), status: .inProgress,
            isArchived: race.isArchived, isMerged: race.isMerged,
            sortOrder: race.sortOrder
        )
        try? store.save(updated)
        let allAthletes = (try? store.fetchAthletes()) ?? []
        liveTimingVM = LiveTimingViewModel(race: updated, athletes: allAthletes, store: store, cache: cache)
        navigateToLiveTiming = true
    }
}
