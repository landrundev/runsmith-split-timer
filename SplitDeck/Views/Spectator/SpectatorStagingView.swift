import SwiftUI

// MARK: - Data Models

private struct AthleteEventStats {
    let athlete: Athlete
    let prMs: Int?
    let prDate: Date?
    let lastRaceMs: Int?
    let racesInEvent: Int
    let bestLapMs: Int?
    let trend: Trend
    let prDiffMs: Int?  // lastRaceMs - prMs (positive = slower than PR, nil if equal or no data)
}

private enum Trend {
    case improving, declining, steady, insufficient

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Slowing Down"
        case .steady: return "Consistent"
        case .insufficient: return ""
        }
    }

    var iconName: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .declining: return "arrow.up.right"
        case .steady: return "arrow.right"
        case .insufficient: return ""
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .orange
        case .steady: return Theme.textSecondary
        case .insufficient: return .clear
        }
    }
}

private struct RelayTeamStats {
    let bestTimeMs: Int?
    let timesRaced: Int
    let lastTimeMs: Int?
}

// MARK: - View

struct SpectatorStagingView: View {
    let race: Race
    let store: SplitDeckStore
    let cache: RaceStateCache
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var navigateToLiveTiming = false
    @State private var liveTimingVM: LiveTimingViewModel?
    @State private var raceCompleted = false

    @State private var athleteStats: [AthleteEventStats] = []
    @State private var relayStats: RelayTeamStats?
    @State private var athletes: [Athlete] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if race.eventType.isRelay {
                        relayContent
                    } else if race.athleteIds.count == 1, let stats = athleteStats.first {
                        singleAthleteContent(stats: stats)
                    } else if race.athleteIds.count > 1 {
                        multiAthleteContent
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
                LiveTimingView(vm: vm, cache: cache, onRaceComplete: {
                    raceCompleted = true
                    onDone()
                })
                .hidesTabBar()
            }
        }
        .onChange(of: navigateToLiveTiming) { isActive in
            if !isActive && raceCompleted {
                dismiss()
            }
        }
        .onAppear { loadStats() }
    }

    // MARK: - Single Athlete Layout

    private func singleAthleteContent(stats: AthleteEventStats) -> some View {
        Group {
            heroAthleteCard(athlete: stats.athlete)

            if stats.racesInEvent > 0 {
                sectionHeader("EVENT HISTORY")
                statsGrid(stats: stats)
                trendBanner(stats: stats)
                prDifferential(stats: stats)
            } else {
                firstRaceCard(eventName: race.eventType.displayName)
            }
        }
    }

    // MARK: - Multi-Athlete Layout

    private var multiAthleteContent: some View {
        Group {
            raceInfoCard

            sectionHeader("\(athleteStats.count) ATHLETES")

            ForEach(athleteStats, id: \.athlete.id) { stats in
                athleteRow(stats: stats)
            }
        }
    }

    // MARK: - Relay Layout

    private var relayContent: some View {
        Group {
            relayTeamCard

            if let stats = relayStats, stats.timesRaced > 0 {
                sectionHeader("TEAM HISTORY")
                relayHistoryCard(stats: stats)
            } else if relayStats != nil {
                firstRaceCard(eventName: race.eventType.displayName)
            }
        }
    }

    // MARK: - Hero Athlete Card

    private func heroAthleteCard(athlete: Athlete) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: athlete.colorHex))
                    .frame(width: 56, height: 56)
                Text(String(athlete.name.prefix(1)).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(athlete.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 4) {
                Text(race.eventType.displayName)
                if !race.isUnlimitedSplits {
                    Text("\u{00B7}")
                    Text("\(race.laps) lap\(race.laps == 1 ? "" : "s")")
                    Text("\u{00B7}")
                    Text("\(race.trackLengthMeters)m track")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Stats Grid (2x2)

    private func statsGrid(stats: AthleteEventStats) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            statCell(
                icon: "trophy",
                value: stats.prMs?.formattedSplitTime ?? "--:--.--",
                label1: "Personal",
                label2: "Best",
                valueColor: stats.prMs != nil ? Theme.runsmithPink : Theme.textMuted
            )
            statCell(
                icon: "number",
                value: "\(stats.racesInEvent)",
                label1: "Times",
                label2: "Raced"
            )
            statCell(
                icon: "clock",
                value: stats.lastRaceMs?.formattedSplitTime ?? "--:--.--",
                label1: "Last",
                label2: "Race",
                valueColor: stats.lastRaceMs != nil ? Theme.textPrimary : Theme.textMuted
            )
            statCell(
                icon: "bolt",
                value: stats.bestLapMs?.formattedSplitTime ?? "--:--.--",
                label1: "Best",
                label2: "Lap",
                valueColor: stats.bestLapMs != nil ? Theme.textPrimary : Theme.textMuted
            )
        }
    }

    private func statCell(
        icon: String, value: String,
        label1: String, label2: String,
        valueColor: Color = Theme.textPrimary
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(valueColor)
            VStack(spacing: 0) {
                Text(label1)
                Text(label2)
            }
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Trend Banner

    @ViewBuilder
    private func trendBanner(stats: AthleteEventStats) -> some View {
        if stats.trend != .insufficient {
            HStack(spacing: 8) {
                Image(systemName: stats.trend.iconName)
                    .font(.subheadline.weight(.semibold))
                Text(stats.trend.label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(stats.trend.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(stats.trend.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }

    // MARK: - PR Differential

    @ViewBuilder
    private func prDifferential(stats: AthleteEventStats) -> some View {
        if let diff = stats.prDiffMs, diff != 0 {
            let sign = diff > 0 ? "+" : ""
            let color: Color = diff > 0 ? .orange : .green
            HStack(spacing: 4) {
                Text("Last race:")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(sign)\(abs(diff).formattedSplitTime) from PR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }

    // MARK: - First Race Card

    private func firstRaceCard(eventName: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.badgeYellow)

            Text("First \(eventName)!")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Every record starts somewhere.\nLet\u{2019}s set a personal best today.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Race Info Card (multi-athlete)

    private var raceInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(race.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                Text(race.eventType.displayName)
                if !race.isUnlimitedSplits {
                    Text("\u{00B7}")
                    Text("\(race.distanceMeters)m")
                    Text("\u{00B7}")
                    Text("\(race.laps) lap\(race.laps == 1 ? "" : "s")")
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

    // MARK: - Athlete Row (multi-athlete)

    private func athleteRow(stats: AthleteEventStats) -> some View {
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

    // MARK: - Relay Team Card

    private var relayTeamCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.runsmithPink)

                Text(race.eventType.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 4) {
                    Text("\(race.athleteIds.count) legs")
                    Text("\u{00B7}")
                    Text("\(race.trackLengthMeters)m each")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // Leg order
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
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Relay History Card

    private func relayHistoryCard(stats: RelayTeamStats) -> some View {
        HStack(spacing: 16) {
            if let best = stats.bestTimeMs {
                VStack(spacing: 2) {
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(best.formattedSplitTime)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                }
            }
            if let last = stats.lastTimeMs, last != stats.bestTimeMs {
                VStack(spacing: 2) {
                    Text("Last")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(last.formattedSplitTime)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            VStack(spacing: 2) {
                Text("Raced")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(stats.timesRaced)\u{00D7}")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Data Loading

    private func loadStats() {
        let allAthletes = (try? store.fetchAthletes()) ?? []
        athletes = race.athleteIds.compactMap { id in allAthletes.first { $0.id == id } }

        if race.eventType.isRelay {
            loadRelayStats()
        } else {
            athleteStats = athletes.map { computeStats(for: $0) }
        }
    }

    private func computeStats(for athlete: Athlete) -> AthleteEventStats {
        let allRaces = (try? store.fetchRaces(forAthlete: athlete.id)) ?? []
        let eventRaces = allRaces
            .filter { $0.status == .completed && $0.eventType == race.eventType }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }

        guard !eventRaces.isEmpty else {
            return AthleteEventStats(
                athlete: athlete, prMs: nil, prDate: nil,
                lastRaceMs: nil, racesInEvent: 0,
                bestLapMs: nil, trend: .insufficient, prDiffMs: nil
            )
        }

        var times: [(ms: Int, date: Date)] = []
        var allLapTimes: [Int] = []

        for pastRace in eventRaces {
            guard let splits = try? store.fetchSplits(for: pastRace.id) else { continue }
            if let finalMs = RaceDomain.finalTime(athlete: athlete, splits: splits, race: pastRace) {
                times.append((ms: finalMs, date: pastRace.startedAt ?? .distantPast))
            }
            // Collect lap times for best lap
            let totalSplits = pastRace.expectedSplitsPerAthlete
            for lapIdx in 1...totalSplits {
                if let lapMs = RaceDomain.lapTime(athlete: athlete, lapIndex: lapIdx, splits: splits) {
                    allLapTimes.append(lapMs)
                }
            }
        }

        let pr = times.min(by: { $0.ms < $1.ms })
        let last = times.first // already sorted newest-first
        let bestLap = allLapTimes.min()
        let trend = computeTrend(from: times.map(\.ms))

        let prDiff: Int?
        if let lastMs = last?.ms, let prMs = pr?.ms, lastMs != prMs {
            prDiff = lastMs - prMs
        } else {
            prDiff = nil
        }

        return AthleteEventStats(
            athlete: athlete,
            prMs: pr?.ms, prDate: pr?.date,
            lastRaceMs: last?.ms,
            racesInEvent: times.count,
            bestLapMs: bestLap,
            trend: trend,
            prDiffMs: prDiff
        )
    }

    private func computeTrend(from times: [Int]) -> Trend {
        // times is ordered newest-first
        guard times.count >= 2 else { return .insufficient }
        let recent = Array(times.prefix(5).reversed()) // chronological: oldest → newest
        var improvements = 0
        var regressions = 0
        for i in 1..<recent.count {
            if recent[i] < recent[i - 1] { improvements += 1 }
            else if recent[i] > recent[i - 1] { regressions += 1 }
        }
        if improvements > regressions { return .improving }
        if regressions > improvements { return .declining }
        return .steady
    }

    private func loadRelayStats() {
        guard let firstId = race.athleteIds.first else { return }
        let allRaces = (try? store.fetchRaces(forAthlete: firstId)) ?? []
        let relayRaces = allRaces.filter { $0.status == .completed && $0.eventType == race.eventType }

        let allAthletes = (try? store.fetchAthletes()) ?? []
        var finalTimes: [(ms: Int, date: Date)] = []

        for pastRace in relayRaces {
            guard let splits = try? store.fetchSplits(for: pastRace.id),
                  let lastAthleteId = pastRace.athleteIds.last,
                  let lastAthlete = allAthletes.first(where: { $0.id == lastAthleteId }),
                  let finalMs = RaceDomain.finalTime(athlete: lastAthlete, splits: splits, race: pastRace)
            else { continue }
            finalTimes.append((ms: finalMs, date: pastRace.startedAt ?? .distantPast))
        }

        let best = finalTimes.min(by: { $0.ms < $1.ms })
        let last = finalTimes.sorted(by: { $0.date > $1.date }).first

        relayStats = RelayTeamStats(
            bestTimeMs: best?.ms,
            timesRaced: finalTimes.count,
            lastTimeMs: last?.ms
        )
    }

    // MARK: - Start Timing

    private func startTiming() {
        let updated = Race(
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
