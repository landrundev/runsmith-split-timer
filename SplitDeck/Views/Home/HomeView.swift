import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var showAddMeet = false
    @State private var showQuickRaceSetup = false
    @State private var showImportRace = false
    @State private var showDrawer = false
    @State private var newMeetName = ""
    @State private var newMeetDate = Date()
    @State private var newMeetLocation = ""

    // Delete confirmation
    @State private var meetToDelete: Meet? = nil
    @State private var quickRaceToDelete: Race? = nil

    // Pending race setup (sheet-based to avoid nested NavigationStack)
    @State private var pendingRaceToSetup: Race? = nil

    // Meet editing
    @State private var meetToEdit: Meet? = nil
    @State private var editMeetName = ""
    @State private var editMeetDate = Date()
    @State private var editMeetLocation = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var pendingQuickRaces: [Race] {
        vm.quickRaces.filter { $0.status == .notStarted }
    }

    private var startedQuickRaces: [Race] {
        vm.quickRaces.filter { $0.status != .notStarted }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                meetList
                bottomBar
                drawerOverlay
            }
            .navigationTitle("Runsmith")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        AthleteRosterView(store: store)
                    } label: {
                        Image(systemName: "person.2")
                    }
                }
                ToolbarItem(placement: .principal) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Image("RunsmithLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddMeet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMeet) {
                addMeetSheet
            }
            .sheet(item: $meetToEdit) { meet in
                editMeetSheet(meet: meet)
            }
            .sheet(isPresented: $showImportRace, onDismiss: { vm.load() }) {
                ImportRaceView(store: store, cache: cache)
            }
            .sheet(isPresented: $showQuickRaceSetup, onDismiss: { vm.load() }) {
                RaceSetupView(
                    vm: RaceSetupViewModel(meetId: nil, store: store),
                    store: store,
                    cache: cache
                )
            }
            .sheet(item: $pendingRaceToSetup, onDismiss: { vm.load() }) { race in
                RaceSetupView(
                    vm: RaceSetupViewModel(meetId: nil, store: store, existingRaceId: race.id),
                    store: store,
                    cache: cache
                )
            }
            .confirmationDialog(
                "Delete \"\(meetToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { meetToDelete != nil },
                    set: { if !$0 { meetToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: meetToDelete
            ) { meet in
                Button("Delete Meet & All Races", role: .destructive) {
                    vm.delete(meet: meet)
                    meetToDelete = nil
                }
                Button("Cancel", role: .cancel) { meetToDelete = nil }
            } message: { _ in
                Text("This will permanently delete the meet and all its races and splits.")
            }
            .confirmationDialog(
                "Delete \"\(quickRaceToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { quickRaceToDelete != nil },
                    set: { if !$0 { quickRaceToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: quickRaceToDelete
            ) { race in
                Button("Delete Race", role: .destructive) {
                    vm.delete(race: race)
                    quickRaceToDelete = nil
                }
                Button("Cancel", role: .cancel) { quickRaceToDelete = nil }
            }
            .onAppear { vm.load() }
        }
    }

    // MARK: – Combined list

    private var meetList: some View {
        List {
            if vm.meets.isEmpty && vm.quickRaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Meets Yet")
                        .font(.headline)
                    Text("Tap + to add a meet or use Quick Race.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TipCardView(
                        tipId: "quickRace",
                        icon: "stopwatch",
                        message: "Quick Race lets you time a race instantly \u{2014} no meet needed. To organize races by event and date, tap + to create a meet first."
                    )
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                TipCardView(
                    tipId: "swipeActions",
                    icon: "hand.draw",
                    message: "Swipe left on any race or meet to edit or delete it. Swipe right to archive it."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !vm.meets.isEmpty {
                    Section("Meets") {
                        ForEach(vm.meets) { meet in
                            NavigationLink {
                                MeetDetailView(
                                    vm: MeetDetailViewModel(meet: meet, store: store),
                                    store: store,
                                    cache: cache
                                )
                            } label: {
                                MeetRowView(meet: meet, raceCount: vm.meetRaces[meet.id]?.count ?? 0, status: vm.meetStatus(for: meet))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    meetToDelete = meet
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editMeetName = meet.name
                                    editMeetDate = meet.date
                                    editMeetLocation = meet.location ?? ""
                                    meetToEdit = meet
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    vm.archive(meet: meet)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }

                if !pendingQuickRaces.isEmpty {
                    Section("Pending Races") {
                        ForEach(pendingQuickRaces) { race in
                            pendingRaceRow(race)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        quickRaceToDelete = race
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
                                    .tint(.orange)
                                }
                        }
                    }
                }

                if !startedQuickRaces.isEmpty {
                    Section("Quick Race History") {
                        ForEach(startedQuickRaces) { race in
                            quickRaceRow(race)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        quickRaceToDelete = race
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
                                    .tint(.orange)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.screenBackground)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
    }

    /// Pending race row — opens sheet instead of push to avoid nested NavigationStack.
    @ViewBuilder
    private func pendingRaceRow(_ race: Race) -> some View {
        Button { pendingRaceToSetup = race } label: {
            HStack(spacing: 0) {
                raceGenderBar(race)
                    .padding(.trailing, 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(race.name)
                        .font(.headline)
                    Text(race.startedAt.map { Self.dateFormatter.string(from: $0) } ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if race.isMerged { waBadge }
                statusBadge(race.status)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func quickRaceRow(_ race: Race) -> some View {
        NavigationLink(destination: quickRaceDestination(race)) {
            HStack(spacing: 0) {
                // Gender color bar
                raceGenderBar(race)
                    .padding(.trailing, 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(race.name)
                        .font(.headline)
                    Text(race.startedAt.map { Self.dateFormatter.string(from: $0) } ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if race.isMerged { waBadge }
                statusBadge(race.status)
            }
            .padding(.vertical, 4)
        }
    }

    /// Gender bar for a race: blue if all male, pink if all female, split gradient if mixed.
    private func raceGenderBar(_ race: Race) -> some View {
        let genders = race.athleteIds.compactMap { id in
            vm.athletes.first(where: { $0.id == id })?.gender
        }
        let hasMale = genders.contains(.male)
        let hasFemale = genders.contains(.female)

        let fill: AnyShapeStyle
        if hasMale && hasFemale {
            fill = AnyShapeStyle(LinearGradient(
                colors: [.blue, Color(hex: "#FF5CA1")],
                startPoint: .top, endPoint: .bottom
            ))
        } else if hasMale {
            fill = AnyShapeStyle(Color.blue)
        } else if hasFemale {
            fill = AnyShapeStyle(Color(hex: "#FF5CA1"))
        } else {
            fill = AnyShapeStyle(Color(.quaternaryLabel))
        }

        return Rectangle()
            .fill(fill)
            .frame(width: 4)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func quickRaceDestination(_ race: Race) -> some View {
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

    private func statusBadge(_ status: RaceStatus) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.statusColor(status).opacity(0.15))
            .foregroundStyle(Theme.statusColor(status))
            .clipShape(Capsule())
    }

    private var waBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark.seal.fill")
            Text("WA")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.green)
        .padding(.trailing, 6)
    }

    // MARK: – Bottom Action Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // Grid icon — opens drawer
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showDrawer = true
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.runsmithPink)
                        .frame(width: 52, height: 52)
                        .background(Theme.runsmithPink.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Quick Race — primary action
                Button {
                    showQuickRaceSetup = true
                } label: {
                    Label("Quick Race", systemImage: "stopwatch")
                }
                .buttonStyle(GlassPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    // MARK: – Drawer Overlay

    private var drawerOverlay: some View {
        ZStack(alignment: .bottom) {
            // Dimmed backdrop
            if showDrawer {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showDrawer = false
                        }
                    }
                    .transition(.opacity)
            }

            // Drawer sheet
            if showDrawer {
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    // Section header
                    HStack {
                        Text("MORE ACTIONS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    // Menu items — least used at top, most used at bottom
                    VStack(spacing: 0) {
                        // Analytics
                        NavigationLink {
                            AnalyticsView(store: store)
                        } label: {
                            drawerRow(
                                icon: "chart.xyaxis.line",
                                title: "Analytics",
                                subtitle: "PRs, leaderboards, and insights"
                            )
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showDrawer = false
                            }
                        })

                        Divider().padding(.leading, 66)

                        // Archive
                        NavigationLink {
                            ArchiveView(vm: ArchiveViewModel(store: store))
                        } label: {
                            drawerRow(
                                icon: "archivebox",
                                title: "Archive",
                                subtitle: "View archived meets and races"
                            )
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showDrawer = false
                            }
                        })

                        Divider().padding(.leading, 66)

                        // Import Race (middle)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showDrawer = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showImportRace = true
                            }
                        } label: {
                            drawerRow(
                                icon: "square.and.arrow.down",
                                title: "Import Race",
                                subtitle: "Scan QR, import file, or paste"
                            )
                        }

                        Divider().padding(.leading, 66)

                        // Relay Builder
                        NavigationLink {
                            RelayBuilderView(
                                vm: RelayBuilderViewModel(store: store)
                            )
                        } label: {
                            drawerRow(
                                icon: "arrow.triangle.branch",
                                title: "Relay Builder",
                                subtitle: "Build and save relay teams"
                            )
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showDrawer = false
                            }
                        })
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGroupedBackground))
                        .ignoresSafeArea(edges: .bottom)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showDrawer)
    }

    private func drawerRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.runsmithPink)
                .frame(width: 36, height: 36)
                .background(Theme.runsmithPink.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: – Edit Meet Sheet

    private func editMeetSheet(meet: Meet) -> some View {
        NavigationStack {
            Form {
                Section("Meet Details") {
                    TextField("Meet Name", text: $editMeetName)
                    DatePicker("Date", selection: $editMeetDate, displayedComponents: .date)
                    TextField("Location (optional)", text: $editMeetLocation)
                }
            }
            .navigationTitle("Edit Meet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { meetToEdit = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = Meet(
                            id: meet.id,
                            name: editMeetName,
                            date: editMeetDate,
                            location: editMeetLocation.isEmpty ? nil : editMeetLocation
                        )
                        vm.save(meet: updated)
                        meetToEdit = nil
                    }
                    .disabled(editMeetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: – Add Meet Sheet

    private var addMeetSheet: some View {
        NavigationStack {
            Form {
                Section("Meet Details") {
                    TextField("Meet Name", text: $newMeetName)
                    DatePicker("Date", selection: $newMeetDate, displayedComponents: .date)
                    TextField("Location (optional)", text: $newMeetLocation)
                }
            }
            .navigationTitle("New Meet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMeet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newMeetName.isEmpty else { return }
                        let meet = Meet(
                            name: newMeetName,
                            date: newMeetDate,
                            location: newMeetLocation.isEmpty ? nil : newMeetLocation
                        )
                        vm.save(meet: meet)
                        newMeetName = ""
                        newMeetDate = Date()
                        newMeetLocation = ""
                        showAddMeet = false
                    }
                    .disabled(newMeetName.isEmpty)
                }
            }
        }
    }
}

// MARK: – Meet Row

struct MeetRowView: View {
    let meet: Meet
    var raceCount: Int = 0
    var status: RaceStatus = .notStarted

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meet.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(Self.dateFormatter.string(from: meet.date))
                    if let loc = meet.location {
                        Text("·")
                        Text(loc)
                    }
                    if raceCount > 0 {
                        Text("·")
                        Text("\(raceCount) race\(raceCount == 1 ? "" : "s")")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.statusColor(status).opacity(0.15))
                .foregroundStyle(Theme.statusColor(status))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
