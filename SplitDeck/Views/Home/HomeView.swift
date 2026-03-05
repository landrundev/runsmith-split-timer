import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var showAddMeet = false
    @State private var showQuickRaceSetup = false
    @State private var newMeetName = ""
    @State private var newMeetDate = Date()
    @State private var newMeetLocation = ""

    // Delete confirmation
    @State private var meetToDelete: Meet? = nil
    @State private var quickRaceToDelete: Race? = nil

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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                meetList
                quickRaceButton
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
            .sheet(isPresented: $showQuickRaceSetup, onDismiss: { vm.load() }) {
                RaceSetupView(
                    vm: RaceSetupViewModel(meetId: nil, store: store),
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
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
                                MeetRowView(meet: meet)
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
                        }
                    }
                }

                if !vm.quickRaces.isEmpty {
                    Section("Quick Race History") {
                        ForEach(vm.quickRaces) { race in
                            quickRaceRow(race)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        quickRaceToDelete = race
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
            EmptyView()
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

    // MARK: – Bottom Action Bar

    private var quickRaceButton: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                NavigationLink {
                    RelayBuilderView(
                        vm: RelayBuilderViewModel(store: store)
                    )
                } label: {
                    Label("Relay Builder", systemImage: "figure.run")
                        .font(.headline)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .tint(Theme.runsmithPink)

                Button {
                    showQuickRaceSetup = true
                } label: {
                    Label("Quick Race", systemImage: "stopwatch")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(.bar)
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(meet.name)
                .font(.headline)
            HStack {
                Text(Self.dateFormatter.string(from: meet.date))
                if let loc = meet.location {
                    Text("·")
                    Text(loc)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
