import SwiftUI

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
    }

    // MARK: – Race Summary Card

    private var raceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(race.name)
                .font(.headline)

            HStack(spacing: 4) {
                Text(race.eventType.displayName)
                Text("\u{00B7}")
                if race.isUnlimitedSplits {
                    Text("Unlimited")
                } else {
                    Text("\(race.distanceMeters)m \u{00B7} \(race.laps) lap\(race.laps == 1 ? "" : "s")")
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
                athleteChips
            }
        }
    }

    private var athleteChips: some View {
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
