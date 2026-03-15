import SwiftUI

// MARK: - Post-Race Insight Models

private struct AthleteInsight: Identifiable {
    var id: UUID { athlete.id }
    let athlete: Athlete
    let finishMs: Int?
    let isPR: Bool
    let previousPrMs: Int?   // their PR before this race (nil if first race)
    let prGapMs: Int?        // finishMs - PR (positive = slower, nil if isPR or first)
    let racesInEvent: Int
    let bestLapMs: Int?      // best lap in THIS race
    let bestLapLabel: String?
}

private struct RelayInsight {
    let isTeamBest: Bool
    let previousBestMs: Int?
    let bestGapMs: Int?
    let timesRaced: Int
    let fastestLegAthlete: Athlete?
    let fastestLegMs: Int?
}

struct ResultsView: View {
    @ObservedObject var vm: ResultsViewModel
    @EnvironmentObject var store: SplitDeckStore
    var onDone: (() -> Void)? = nil
    @State private var shareItem: SharePreviewItem? = nil
    @State private var showExport = false
    @State private var showMerge = false
    @State private var athleteInsights: [AthleteInsight] = []
    @State private var relayInsight: RelayInsight?
    @State private var showOfficialEntry = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWideLayout: Bool { sizeClass == .regular }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var manualFinalMsForOfficialEntry: Int? {
        guard let entry = vm.rankedAthletes.first,
              vm.race.meetId == nil,
              vm.athletes.count == 1 else { return nil }
        // Use the split's elapsedMs directly (not officialFinalMs) since we want
        // the original manual time as the starting point for the official entry.
        let splits = vm.splits.filter { $0.athleteId == entry.athlete.id }
        guard let finalSplit = splits.first(where: { $0.lapIndex == vm.race.laps }) else { return nil }
        return finalSplit.elapsedMs
    }

    var body: some View {
        VStack(spacing: 0) {
            raceInfoHeader
            TipCardView(
                tipId: "coachMerge",
                icon: "person.2.badge.gearshape",
                message: "Tap the \u{00B7}\u{00B7}\u{00B7} menu to share or merge splits. Use Export for Merge to send your splits to a head coach via QR code. Use Merge Coach Data if you\u{2019}re the head coach combining splits from assistants."
            )

            Picker("Display", selection: $vm.displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            if vm.race.eventType.isRelay {
                relayResultsTable
            } else {
                resultsTable
            }
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onDone != nil)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        let data = vm.buildCardData()
                        shareItem = SharePreviewItem(image: CardRenderer.render(data: data))
                    } label: {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showExport = true
                    } label: {
                        Label("Export for Merge", systemImage: "arrow.up.doc")
                    }

                    Button {
                        showMerge = true
                    } label: {
                        Label("Merge Coach Data", systemImage: "person.2.badge.gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if onDone != nil {
                doneButton
            }
        }
        .adaptiveSheet(isPresented: $showExport) {
            ExportSplitsView(payload: vm.buildCoachSplitPayload())
        }
        .adaptiveSheet(isPresented: $showMerge) {
            MergeView(vm: MergeViewModel(
                race: vm.race,
                athletes: vm.orderedAthletes,
                hostSplits: vm.splits,
                store: store
            ))
        }
        .adaptiveSheet(item: $shareItem) { item in
            SharePreviewSheet(image: item.image, csvURL: vm.csvFileURL())
        }
        .sheet(isPresented: $showOfficialEntry) {
            if let ms = manualFinalMsForOfficialEntry {
                OfficialTimeEntryView(
                    race: vm.race,
                    manualFinalMs: ms,
                    store: store,
                    onSaved: { showOfficialEntry = false }
                )
            }
        }
    }

    // MARK: – Race Info Header

    private var raceInfoHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.race.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Text(vm.race.eventType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                if let meet = vm.meet {
                    Text("\u{00B7}").foregroundStyle(Theme.textTertiary)
                    Text(meet.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                if let date = vm.race.startedAt {
                    Text("\u{00B7}").foregroundStyle(Theme.textTertiary)
                    Text(Self.dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if vm.race.isMerged {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("WA Official")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }

            // Official time badge (spectator mode)
            if vm.race.isOfficiallyTimed, let offMs = vm.race.officialFinalMs {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Official \u{00B7} \(offMs.formattedSplitTime)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }

            // Add official time prompt (spectator single-athlete non-meet races)
            if !vm.race.isOfficiallyTimed && !vm.race.isMerged
               && vm.race.meetId == nil && vm.athletes.count == 1 {
                if manualFinalMsForOfficialEntry != nil {
                    Button {
                        showOfficialEntry = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add Official Time")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.runsmithPink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
    }

    // MARK: – Done Button (bottom)

    private var doneButton: some View {
        Button {
            onDone?()
        } label: {
            Text("Done")
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .glassActionBar()
    }

    // MARK: – Individual Results Table

    private var resultsTable: some View {
        ScrollView(.vertical) {
            if isWideLayout {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 0
                ) {
                    ForEach(vm.rankedAthletes, id: \.athlete.id) { entry in
                        VStack(spacing: 0) {
                            athleteBlock(entry: entry)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(vm.rankedAthletes, id: \.athlete.id) { entry in
                        athleteBlock(entry: entry)
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
            }

            if !athleteInsights.isEmpty {
                insightsSection
            }
        }
        .onAppear { loadInsights() }
    }

    private func athleteBlock(entry: (athlete: Athlete, place: Int?)) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Theme.genderColor(entry.athlete.gender))
                .frame(width: 4)
                .clipShape(Capsule())
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 8) {

                // Name + total time row (always full width, no scroll)
                HStack(spacing: 6) {
                    Text(entry.place.map { "\($0)" } ?? "\u{2014}")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, alignment: .leading)

                    Circle()
                        .fill(Color(hex: entry.athlete.colorHex))
                        .frame(width: 10, height: 10)

                    Text(entry.athlete.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    let finalVal = vm.totalTimeValue(athlete: entry.athlete)
                    if case .missing = finalVal, entry.place == nil {
                        Text("DNF")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                    } else {
                        Text(finalVal.displayString)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(entry.place != nil ? Theme.textPrimary : Theme.textTertiary)
                    }
                }

                // Split columns — wrapping rows (max 4 per row)
                if !vm.columnLabels.isEmpty {
                    wrappingSplitColumns(athlete: entry.athlete, labels: vm.columnLabels)
                }
            }
        }
        .padding(.vertical, 12)
    }

    /// Max columns per row before wrapping.
    private var columnsPerRow: Int { isWideLayout ? 6 : 4 }

    /// Chunks column indices into rows of columnsPerRow, filling top rows first.
    private func splitColumnRows(count: Int) -> [[Int]] {
        guard count > 0 else { return [] }
        let max = columnsPerRow
        var rows: [[Int]] = []
        var idx = 0
        while idx < count {
            let end = Swift.min(idx + max, count)
            rows.append(Array(idx..<end))
            idx = end
        }
        return rows
    }

    /// Renders wrapping split columns for one athlete (max 4 per row, balanced).
    private func wrappingSplitColumns(athlete: Athlete, labels: [String]) -> some View {
        let rows = splitColumnRows(count: labels.count)

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(labels[i])
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            let val = vm.cellValue(athlete: athlete, splitOrdinal: i + 1)
                            Text(val.displayString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: – Relay Results Table

    private var relayResultsTable: some View {
        let hasIntermediates = vm.race.splitsPerLap > 1

        return ScrollView(.vertical) {
            // Center relay table with max width on iPad
            Group {
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("Leg")
                        .frame(width: 36, alignment: .leading)
                    Text("Athlete")
                    Spacer()
                    Text(vm.displayMode == .cumulative ? "Cumulative" : "Leg Time")
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(Array(vm.relayLegData.enumerated()), id: \.element.leg) { i, entry in
                    VStack(spacing: 0) {
                        // Main leg row
                        HStack(spacing: 8) {
                            Text("\(entry.leg)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 36, alignment: .leading)

                            Circle()
                                .fill(Color(hex: entry.athlete.colorHex))
                                .frame(width: 10, height: 10)

                            Text(entry.athlete.firstName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if vm.displayMode == .cumulative {
                                Text(entry.cumulativeMs.map { $0.formattedSplitTime } ?? "\u{2014}")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 90, alignment: .trailing)
                            } else {
                                Text(entry.legMs.map { $0.formattedSplitTime } ?? "\u{2014}")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Intermediate split sub-row (when enabled)
                        if hasIntermediates {
                            let details = RaceDomain.relayLegIntermediateSplits(
                                legIndex: i,
                                athletes: vm.orderedAthletes,
                                splits: vm.splits,
                                race: vm.race
                            )
                            if !details.isEmpty {
                                HStack(alignment: .bottom, spacing: 12) {
                                    Spacer()
                                        .frame(width: 36)
                                    ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                                        VStack(spacing: 1) {
                                            Text(detail.label)
                                                .font(.system(size: 10))
                                                .foregroundStyle(Theme.textTertiary)
                                            Text(detail.lapMs.formattedSplitTime)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    if vm.displayMode == .cumulative {
                                        Text("(\(entry.legMs.map { $0.formattedSplitTime } ?? "\u{2014}"))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                        }
                    }

                    Divider()
                }

                // Total row
                if let total = vm.totalRelayMs {
                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(total.formattedSplitTime)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.cardBackground)
                }
            }
            }
            .frame(maxWidth: isWideLayout ? 800 : .infinity)

            if relayInsight != nil {
                relayInsightsSection
            }
        }
        .onAppear { loadInsights() }
    }

    // MARK: – Post-Race Insights (Individual)

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POST-RACE INSIGHTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            ForEach(athleteInsights) { insight in
                insightCard(insight: insight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func insightCard(insight: AthleteInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Athlete header
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: insight.athlete.colorHex))
                    .frame(width: 10, height: 10)
                Text(insight.athlete.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            // PR status
            if insight.isPR, insight.finishMs != nil {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.runsmithPink)
                    Text("NEW PR!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.runsmithPink)
                    if let prev = insight.previousPrMs {
                        Text("(prev: \(prev.formattedSplitTime))")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            } else if let gap = insight.prGapMs, let pr = insight.previousPrMs {
                HStack(spacing: 4) {
                    Text("+\(gap.formattedSplitTime) off PR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("(\(pr.formattedSplitTime))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else if insight.racesInEvent <= 1, insight.finishMs != nil {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.badgeYellow)
                    Text("First \(vm.race.eventType.displayName) recorded!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Stats row
            HStack(spacing: 16) {
                if insight.racesInEvent > 1 {
                    VStack(spacing: 0) {
                        Text("\(insight.racesInEvent)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text("races")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                if let bestLap = insight.bestLapMs, let label = insight.bestLapLabel {
                    VStack(spacing: 0) {
                        Text(bestLap.formattedSplitTime)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text("best lap (\(label))")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: – Post-Race Insights (Relay)

    private var relayInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POST-RACE INSIGHTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            if let ri = relayInsight {
                relayInsightCard(ri: ri)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func relayInsightCard(ri: RelayInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Team best status
            if ri.isTeamBest {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.runsmithPink)
                    Text("NEW TEAM BEST!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.runsmithPink)
                    if let prev = ri.previousBestMs {
                        Text("(prev: \(prev.formattedSplitTime))")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            } else if let gap = ri.bestGapMs, let best = ri.previousBestMs {
                HStack(spacing: 4) {
                    Text("+\(gap.formattedSplitTime) off best")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("(\(best.formattedSplitTime))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else if ri.timesRaced <= 1 {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.badgeYellow)
                    Text("First \(vm.race.eventType.displayName) recorded!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Stats
            HStack(spacing: 16) {
                if ri.timesRaced > 1 {
                    VStack(spacing: 0) {
                        Text("\(ri.timesRaced)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text("times raced")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                if let athlete = ri.fastestLegAthlete, let ms = ri.fastestLegMs {
                    VStack(spacing: 0) {
                        Text(ms.formattedSplitTime)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text("fastest leg (\(athlete.firstName))")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: – Insight Computation

    private func loadInsights() {
        if vm.race.eventType.isRelay {
            loadRelayInsight()
        } else {
            loadAthleteInsights()
        }
    }

    private func loadAthleteInsights() {
        let athletes = vm.orderedAthletes
        athleteInsights = athletes.compactMap { athlete in
            let finishMs = RaceDomain.finalTime(athlete: athlete, splits: vm.splits, race: vm.race)

            // Historical races for this event
            let allRaces = (try? store.fetchRaces(forAthlete: athlete.id)) ?? []
            let eventRaces = allRaces.filter {
                $0.status == .completed && $0.eventType == vm.race.eventType && $0.id != vm.race.id
            }

            // Prior PR (excluding this race)
            var priorPrMs: Int?
            for past in eventRaces {
                guard let splits = try? store.fetchSplits(for: past.id),
                      let ms = RaceDomain.finalTime(athlete: athlete, splits: splits, race: past)
                else { continue }
                if priorPrMs == nil || ms < priorPrMs! { priorPrMs = ms }
            }

            let racesInEvent = eventRaces.count + (finishMs != nil ? 1 : 0)
            let isPR: Bool
            let prGap: Int?
            if let finish = finishMs {
                if let prior = priorPrMs {
                    isPR = finish <= prior
                    prGap = isPR ? nil : (finish - prior)
                } else {
                    isPR = true  // first race = automatic PR
                    prGap = nil
                }
            } else {
                isPR = false
                prGap = nil
            }

            // Best lap in THIS race
            let totalSplits = vm.race.isUnlimitedSplits ? vm.splits.filter({ $0.athleteId == athlete.id }).count : vm.race.expectedSplitsPerAthlete
            var bestLapMs: Int?
            var bestLapLabel: String?
            let splitDist = vm.race.isUnlimitedSplits ? nil : vm.race.trackLengthMeters / max(vm.race.splitsPerLap, 1)
            for idx in 1...max(totalSplits, 1) {
                if let lapMs = RaceDomain.lapTime(athlete: athlete, lapIndex: idx, splits: vm.splits) {
                    if bestLapMs == nil || lapMs < bestLapMs! {
                        bestLapMs = lapMs
                        if let dist = splitDist {
                            bestLapLabel = "\(dist * idx)m"
                        } else {
                            bestLapLabel = "Split \(idx)"
                        }
                    }
                }
            }

            // Only show insight if there's something meaningful
            guard finishMs != nil || racesInEvent > 0 else { return nil }

            return AthleteInsight(
                athlete: athlete,
                finishMs: finishMs,
                isPR: isPR,
                previousPrMs: priorPrMs,
                prGapMs: prGap,
                racesInEvent: racesInEvent,
                bestLapMs: bestLapMs,
                bestLapLabel: bestLapLabel
            )
        }
    }

    private func loadRelayInsight() {
        guard vm.race.eventType.isRelay else { return }
        let totalMs = vm.totalRelayMs

        // Find prior relay races of same event type
        guard let firstId = vm.race.athleteIds.first else { return }
        let allRaces = (try? store.fetchRaces(forAthlete: firstId)) ?? []
        let priorRelays = allRaces.filter {
            $0.status == .completed && $0.eventType == vm.race.eventType && $0.id != vm.race.id
        }

        let allAthletes = (try? store.fetchAthletes()) ?? []
        var priorTimes: [Int] = []
        for past in priorRelays {
            guard let splits = try? store.fetchSplits(for: past.id),
                  let lastId = past.athleteIds.last,
                  let lastAthlete = allAthletes.first(where: { $0.id == lastId }),
                  let ms = RaceDomain.finalTime(athlete: lastAthlete, splits: splits, race: past)
            else { continue }
            priorTimes.append(ms)
        }

        let priorBest = priorTimes.min()
        let timesRaced = priorTimes.count + (totalMs != nil ? 1 : 0)

        let isTeamBest: Bool
        let bestGap: Int?
        if let total = totalMs {
            if let prior = priorBest {
                isTeamBest = total <= prior
                bestGap = isTeamBest ? nil : (total - prior)
            } else {
                isTeamBest = true
                bestGap = nil
            }
        } else {
            isTeamBest = false
            bestGap = nil
        }

        // Fastest leg
        let legData = vm.relayLegData
        var fastestAthlete: Athlete?
        var fastestMs: Int?
        for entry in legData {
            if let ms = entry.legMs, (fastestMs == nil || ms < fastestMs!) {
                fastestMs = ms
                fastestAthlete = entry.athlete
            }
        }

        relayInsight = RelayInsight(
            isTeamBest: isTeamBest,
            previousBestMs: priorBest,
            bestGapMs: bestGap,
            timesRaced: timesRaced,
            fastestLegAthlete: fastestAthlete,
            fastestLegMs: fastestMs
        )
    }
}

// MARK: – Share Preview

private struct SharePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct SharePreviewSheet: View {
    let image: UIImage
    let csvURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var savedToPhotos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Share Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        withAnimation { savedToPhotos = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedToPhotos = false }
                        }
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save",
                              systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                    }
                    Button {
                        var items: [Any] = [image]
                        if let url = csvURL { items.append(url) }
                        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = scene.windows.first?.rootViewController {
                            var topVC = rootVC
                            while let presented = topVC.presentedViewController { topVC = presented }
                            avc.popoverPresentationController?.barButtonItem = nil
                            topVC.present(avc, animated: true)
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
