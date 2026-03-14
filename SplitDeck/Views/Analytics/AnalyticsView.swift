import SwiftUI

struct AnalyticsView: View {
    @StateObject private var vm: AnalyticsViewModel
    @State private var selectedTab = 0
    @State private var expandedPREvents: Set<EventType> = []
    @State private var prGenderFilter: Gender? = nil
    @State private var prEventFilter: EventType? = nil
    @State private var prTimeSource: AnalyticsViewModel.TimeSourceFilter = .all
    @State private var lbTimeSource: AnalyticsViewModel.TimeSourceFilter = .all
    @State private var athleteGenderFilter: Gender? = nil
    @State private var athleteSearchText: String = ""
    @State private var profileAthlete: Athlete? = nil

    private let store: SplitDeckStore

    /// Distance-based sort order: shortest \u{2192} longest, Custom last.
    private static let eventSortOrder: [EventType] = [
        .m100, .m200, .m400, .m800, .m1500, .mile, .m1600, .m3200, .m5000, .m10000, .custom
    ]

    private func eventSortIndex(_ event: EventType) -> Int {
        Self.eventSortOrder.firstIndex(of: event) ?? Self.eventSortOrder.count
    }

    init(store: SplitDeckStore) {
        self.store = store
        _vm = StateObject(wrappedValue: AnalyticsViewModel(store: store))
    }

    private let tabs = ["Overview", "PRs", "Leaderboard", "Athletes", "Highlights"]

    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented tab bar \u{2014} scrollable
            tabBar

            // Tab content
            TabView(selection: $selectedTab) {
                overviewTab.tag(0)
                prBoardTab.tag(1)
                leaderboardTab.tag(2)
                athletesTab.tag(3)
                highlightsTab.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .navigationDestination(isPresented: Binding(
            get: { profileAthlete != nil },
            set: { if !$0 { profileAthlete = nil } }
        )) {
            if let athlete = profileAthlete {
                AthleteProfileView(
                    vm: AthleteProfileViewModel(athlete: athlete, store: store),
                    store: store
                )
                .hidesTabBar()
            }
        }
    }

    // MARK: \u{2013} Tab Bar

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = i
                            }
                        } label: {
                            Text(tabs[i])
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTab == i
                                        ? Theme.runsmithPink
                                        : Theme.elevatedBackground
                                )
                                .foregroundStyle(selectedTab == i ? .white : Theme.textPrimary)
                                .clipShape(Capsule())
                        }
                        .id(i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Theme.screenBackground)
            .onChange(of: selectedTab) { newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: \u{2013} Tab 0: Overview

    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Season counters grid
                let stats = vm.seasonStats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    statCard(value: "\(stats.totalRaces)", label: "Races", icon: "stopwatch")
                    statCard(value: "\(stats.totalAthletes)", label: "Athletes", icon: "person.3")
                    statCard(value: "\(stats.totalMeets)", label: "Meets", icon: "calendar")
                    statCard(value: "\(stats.totalSplitsRecorded)", label: "Splits", icon: "chart.bar")
                }

                // Date range
                if let first = stats.firstRaceDate, let last = stats.lastRaceDate {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(first, format: .dateTime.month().day()) \u{2013} \(last, format: .dateTime.month().day().year())")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                // Quick highlights preview
                if !vm.raceHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HIGHLIGHTS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .tracking(0.5)

                        ForEach(vm.raceHighlights.prefix(3)) { highlight in
                            highlightRow(highlight)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.runsmithPink)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: \u{2013} Tab 1: PR Board

    private var prBoardTab: some View {
        VStack(spacing: 0) {
            // Filters
            VStack(spacing: 10) {
                // Event picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        eventPill("All", event: nil, selection: $prEventFilter)
                        ForEach(Self.eventSortOrder, id: \.self) { event in
                            eventPill(event.displayName, event: event, selection: $prEventFilter)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Gender filter + source toggle
                HStack(spacing: 6) {
                    filterPill("All", gender: nil, selection: $prGenderFilter)
                    filterPill("M", gender: .male, selection: $prGenderFilter)
                    filterPill("F", gender: .female, selection: $prGenderFilter)
                    Spacer()
                    Picker("Source", selection: $prTimeSource) {
                        ForEach(AnalyticsViewModel.TimeSourceFilter.allCases, id: \.self) { src in
                            Text(src.rawValue).tag(src)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .background(Theme.screenBackground)

        ScrollView {
            if vm.prBoard.isEmpty {
                emptyState(icon: "trophy", message: "No completed races yet")
            } else {
                LazyVStack(spacing: 16) {
                    let sourceFiltered: [AnalyticsViewModel.PREntry] = {
                        switch prTimeSource {
                        case .all: return vm.prBoard
                        case .race: return vm.prBoard.filter { !$0.isSplit }
                        case .split: return vm.prBoard.filter { $0.isSplit }
                        }
                    }()
                    let genderFiltered = prGenderFilter == nil
                        ? sourceFiltered
                        : sourceFiltered.filter { $0.athlete.gender == prGenderFilter }
                    let filtered = prEventFilter == nil
                        ? genderFiltered
                        : genderFiltered.filter { $0.eventType == prEventFilter }
                    let grouped = Dictionary(grouping: filtered, by: \.eventType)
                    let sortedEvents = grouped.keys.sorted { eventSortIndex($0) < eventSortIndex($1) }

                    ForEach(sortedEvents, id: \.self) { event in
                        let entries = grouped[event] ?? []
                        let isExpanded = expandedPREvents.contains(event)
                        let visible = isExpanded ? entries : Array(entries.prefix(5))

                        VStack(alignment: .leading, spacing: 8) {
                            // Event header
                            Text(event.displayName)
                                .font(.headline)
                                .padding(.horizontal, 4)

                            // Grouped card with dividers
                            VStack(spacing: 0) {
                                ForEach(visible.indices, id: \.self) { i in
                                    Button {
                                        profileAthlete = visible[i].athlete
                                    } label: {
                                        prRow(visible[i])
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if i < visible.count - 1 {
                                        Divider().padding(.leading, 38)
                                    }
                                }

                                // Expand / Collapse
                                if entries.count > 5 {
                                    Divider().padding(.leading, 38)
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isExpanded {
                                                expandedPREvents.remove(event)
                                            } else {
                                                expandedPREvents.insert(event)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Text(isExpanded ? "Show Less" : "Show All \(entries.count)")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Theme.runsmithPink)
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                        }
                    }
                }
                .padding(16)
            }
        }
        }
        .background(Theme.screenBackground)
    }

    private func prRow(_ entry: AnalyticsViewModel.PREntry) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.genderColor(entry.athlete.gender))
                .frame(width: 4, height: 32)
                .clipShape(Capsule())

            Circle()
                .fill(Color(hex: entry.athlete.colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.athlete.name)
                    .font(.body.weight(.medium))
                if let date = entry.prDate {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.prMs.formattedSplitTime)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    if entry.isSplit {
                        Text("(split)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }

                Text("\(entry.raceCount) race\(entry.raceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: \u{2013} Tab 2: Leaderboard

    private var leaderboardTab: some View {
        VStack(spacing: 0) {
            // Filters
            VStack(spacing: 10) {
                // Event picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Self.eventSortOrder, id: \.self) { event in
                            Button {
                                vm.selectedEvent = event
                                vm.refreshLeaderboard()
                            } label: {
                                Text(event.displayName)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        vm.selectedEvent == event
                                            ? Theme.runsmithPink
                                            : Theme.elevatedBackground
                                    )
                                    .foregroundStyle(vm.selectedEvent == event ? .white : Theme.textPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Gender filter + source toggle
                HStack(spacing: 6) {
                    genderPill("All", gender: nil)
                    genderPill("M", gender: .male)
                    genderPill("F", gender: .female)
                    Spacer()
                    Picker("Source", selection: $lbTimeSource) {
                        ForEach(AnalyticsViewModel.TimeSourceFilter.allCases, id: \.self) { src in
                            Text(src.rawValue).tag(src)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .background(Theme.screenBackground)

            // Leaderboard list
            ScrollView {
                let filteredLeaderboard: [AnalyticsViewModel.LeaderboardEntry] = {
                    switch lbTimeSource {
                    case .all:
                        // Dedup: per athlete, keep best time
                        var bestByAthlete: [UUID: AnalyticsViewModel.LeaderboardEntry] = [:]
                        for entry in vm.eventLeaderboard {
                            if let existing = bestByAthlete[entry.athlete.id] {
                                if entry.bestMs < existing.bestMs {
                                    bestByAthlete[entry.athlete.id] = entry
                                }
                            } else {
                                bestByAthlete[entry.athlete.id] = entry
                            }
                        }
                        return bestByAthlete.values.sorted { $0.bestMs < $1.bestMs }
                    case .race: return vm.eventLeaderboard.filter { !$0.isSplit }
                    case .split: return vm.eventLeaderboard.filter { $0.isSplit }
                    }
                }()

                if filteredLeaderboard.isEmpty {
                    emptyState(icon: "list.number", message: "No results for \(vm.selectedEvent.displayName)")
                } else {
                    VStack(spacing: 0) {
                        ForEach(filteredLeaderboard.indices, id: \.self) { i in
                            Button {
                                profileAthlete = filteredLeaderboard[i].athlete
                            } label: {
                                leaderboardRow(filteredLeaderboard[i], displayRank: i + 1)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if i < filteredLeaderboard.count - 1 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .padding(16)
                }
            }
        }
        .background(Theme.screenBackground)
    }

    private func eventPill(_ label: String, event: EventType?, selection: Binding<EventType?>) -> some View {
        Button {
            selection.wrappedValue = event
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selection.wrappedValue == event
                        ? Theme.runsmithPink
                        : Theme.elevatedBackground
                )
                .foregroundStyle(selection.wrappedValue == event ? .white : Theme.textPrimary)
                .clipShape(Capsule())
        }
    }

    private func filterPill(_ label: String, gender: Gender?, selection: Binding<Gender?>) -> some View {
        Button {
            selection.wrappedValue = gender
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selection.wrappedValue == gender
                        ? Theme.runsmithPink.opacity(0.15)
                        : Theme.elevatedBackground
                )
                .foregroundStyle(selection.wrappedValue == gender ? Theme.runsmithPink : Theme.textPrimary)
                .clipShape(Capsule())
        }
    }

    private func genderPill(_ label: String, gender: Gender?) -> some View {
        Button {
            vm.selectedGender = gender
            vm.refreshLeaderboard()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    vm.selectedGender == gender
                        ? Theme.runsmithPink.opacity(0.15)
                        : Theme.elevatedBackground
                )
                .foregroundStyle(vm.selectedGender == gender ? Theme.runsmithPink : Theme.textPrimary)
                .clipShape(Capsule())
        }
    }

    private func leaderboardRow(_ entry: AnalyticsViewModel.LeaderboardEntry, displayRank: Int) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.genderColor(entry.athlete.gender))
                .frame(width: 4, height: 36)
                .clipShape(Capsule())

            // Rank
            Text("\(displayRank)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(displayRank <= 3 ? Theme.runsmithPink : Theme.textSecondary)
                .frame(width: 32)

            Circle()
                .fill(Color(hex: entry.athlete.colorHex))
                .frame(width: 10, height: 10)

            Text(entry.athlete.name)
                .font(.body.weight(.medium))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.bestMs.formattedSplitTime)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    if entry.isSplit {
                        Text("(split)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }

                Text("\(entry.raceCount)\u{00D7}")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: \u{2013} Tab 3: Athletes

    private var athletesTab: some View {
        ScrollView {
            if vm.athleteInsights.isEmpty {
                emptyState(icon: "person.3", message: "No athlete data yet")
            } else {
                LazyVStack(spacing: 12) {
                    // Gender filter + Search
                    HStack(spacing: 8) {
                        filterPill("All", gender: nil, selection: $athleteGenderFilter)
                        filterPill("M", gender: .male, selection: $athleteGenderFilter)
                        filterPill("F", gender: .female, selection: $athleteGenderFilter)

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Search", text: $athleteSearchText)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.elevatedBackground)
                        .clipShape(Capsule())
                        .frame(maxWidth: 160)
                    }

                    let genderFiltered = athleteGenderFilter == nil
                        ? vm.athleteInsights
                        : vm.athleteInsights.filter { $0.athlete.gender == athleteGenderFilter }
                    let filtered = athleteSearchText.isEmpty
                        ? genderFiltered
                        : genderFiltered.filter { $0.athlete.name.localizedCaseInsensitiveContains(athleteSearchText) }

                    ForEach(filtered) { insight in
                        Button {
                            profileAthlete = insight.athlete
                        } label: {
                            athleteInsightCard(insight)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.screenBackground)
    }

    private func athleteInsightCard(_ insight: AnalyticsViewModel.AthleteInsight) -> some View {
        HStack(spacing: 0) {
            // Gender color bar
            Rectangle()
                .fill(Theme.genderColor(insight.athlete.gender))
                .frame(width: 4)
                .clipShape(Capsule())
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: insight.athlete.colorHex))
                        .frame(width: 12, height: 12)

                    Text(insight.athlete.name)
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(insight.totalRaces) race\(insight.totalRaces == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                // Stats grid \u{2014} 2 columns to prevent cramping on smaller devices
                let statItems = buildStatItems(insight)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(statItems.indices, id: \.self) { i in
                        miniStat(
                            label: statItems[i].label,
                            value: statItems[i].value,
                            sub: statItems[i].sub
                        )
                    }
                }

                // PR trend sparkline
                if insight.prTrend.count >= 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PR TREND")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .tracking(0.5)

                        SparklineView(
                            points: insight.prTrend.map { Double($0.ms) },
                            color: Theme.runsmithPink
                        )
                        .frame(height: 40)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private struct StatItem {
        let label: String
        let value: String
        let sub: String
    }

    private func buildStatItems(_ insight: AnalyticsViewModel.AthleteInsight) -> [StatItem] {
        var items: [StatItem] = []
        if let event = insight.bestEvent, let ms = insight.bestTimeMs {
            items.append(StatItem(label: "Best", value: ms.formattedSplitTime, sub: event.displayName))
        }
        if let consistency = insight.consistencyScore {
            items.append(StatItem(label: "Consistency", value: formatConsistency(consistency), sub: "lap std dev"))
        }
        if let negRate = insight.negativeSplitRate {
            items.append(StatItem(label: "Neg. Split", value: "\(Int(negRate * 100))%", sub: "of races"))
        }
        if let fastest = insight.fastestLapMs {
            items.append(StatItem(label: "Fast Lap", value: fastest.formattedSplitTime, sub: "best single"))
        }
        return items
    }

    private func miniStat(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))

            Text(sub)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func formatConsistency(_ ms: Double) -> String {
        let seconds = ms / 1000.0
        return String(format: "%.1fs", seconds)
    }

    // MARK: \u{2013} Tab 4: Highlights

    private var highlightsTab: some View {
        ScrollView {
            if vm.raceHighlights.isEmpty {
                emptyState(icon: "sparkles", message: "Race more to unlock highlights")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vm.raceHighlights) { highlight in
                        highlightCard(highlight)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.screenBackground)
    }

    private func highlightCard(_ highlight: AnalyticsViewModel.RaceHighlight) -> some View {
        HStack(spacing: 14) {
            Image(systemName: highlight.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.runsmithPink)
                .frame(width: 44, height: 44)
                .background(Theme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .font(.headline)
                Text(highlight.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text(highlight.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: \u{2013} Highlight Row (compact, for Overview tab)

    private func highlightRow(_ highlight: AnalyticsViewModel.RaceHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.runsmithPink)
                .frame(width: 32, height: 32)
                .background(Theme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.title)
                    .font(.subheadline.weight(.medium))
                Text(highlight.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: \u{2013} Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: \u{2013} Sparkline

struct SparklineView: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minVal = points.min() ?? 0
            let maxVal = points.max() ?? 1
            let range = max(maxVal - minVal, 1)

            Path { path in
                for (i, value) in points.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                    // Invert Y: lower time = higher on chart (better performance = up)
                    let y = geo.size.height * (1.0 - CGFloat((value - minVal) / range))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
