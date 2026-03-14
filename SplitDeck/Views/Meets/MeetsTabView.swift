import SwiftUI

struct MeetsTabView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var showAddMeet = false
    @State private var showImportRace = false
    @State private var navigationPath = NavigationPath()
    @State private var newlyCreatedMeet: Meet? = nil

    // Meet form fields
    @State private var newMeetName = ""
    @State private var newMeetDate = Date()
    @State private var newMeetLocation = ""

    // Edit meet
    @State private var meetToEdit: Meet? = nil
    @State private var editMeetName = ""
    @State private var editMeetDate = Date()
    @State private var editMeetLocation = ""

    // Delete confirmation
    @State private var meetToDelete: Meet? = nil

    // MARK: \u{2013} Computed Sections

    /// Non-archived meets with an in-progress race.
    private var liveMeets: [Meet] {
        vm.meets.filter { !$0.isArchived && vm.meetStatus(for: $0) == .inProgress }
    }

    /// Non-archived, non-live meets whose date is within the current school year
    /// (roughly Aug 1 of previous year through Jul 31 of current year).
    private var thisSeasonMeets: [Meet] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        // School year: Aug-Jul. If before August, season started last year.
        let seasonStartYear = month >= 8 ? year : year - 1
        let seasonStart = calendar.date(from: DateComponents(year: seasonStartYear, month: 8, day: 1))!
        let seasonEnd = calendar.date(from: DateComponents(year: seasonStartYear + 1, month: 7, day: 31))!

        return vm.meets.filter { meet in
            !meet.isArchived
            && vm.meetStatus(for: meet) != .inProgress
            && meet.date >= seasonStart
            && meet.date <= seasonEnd
        }
        .sorted { $0.date > $1.date }
    }

    /// Archived meets \u{2013} fetched separately since fetchMeets() excludes them.
    private var archivedMeets: [Meet] {
        vm.archivedMeets.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                if vm.meets.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        if !liveMeets.isEmpty {
                            meetSection(title: "Live", meets: liveMeets)
                        }
                        if !thisSeasonMeets.isEmpty {
                            meetSection(title: "This Season", meets: thisSeasonMeets)
                        }
                        if !archivedMeets.isEmpty {
                            meetSection(title: "Archived", meets: archivedMeets)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle("Meets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddMeet = true
                        } label: {
                            Label("New Meet", systemImage: "plus")
                        }

                        Button {
                            showImportRace = true
                        } label: {
                            Label("Import Race", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImportRace, onDismiss: { vm.load() }) {
                ImportRaceView(store: store)
            }
            .sheet(isPresented: $showAddMeet, onDismiss: {
                if let meet = newlyCreatedMeet {
                    navigationPath.append(meet)
                    newlyCreatedMeet = nil
                }
            }) {
                addMeetSheet
            }
            .sheet(item: $meetToEdit) { meet in
                editMeetSheet(meet: meet)
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
            .onAppear { vm.load() }
            .navigationDestination(for: Meet.self) { meet in
                MeetDetailView(
                    vm: MeetDetailViewModel(meet: meet, store: store),
                    store: store,
                    cache: cache
                )
                .hidesTabBar()
            }
        }
    }

    // MARK: \u{2013} Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textMuted)
            Text("No Meets Yet")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tap + to create your first meet.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: \u{2013} Section Builder

    @ViewBuilder
    private func meetSection(title: String, meets: [Meet]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(meets) { meet in
                    NavigationLink(value: meet) {
                        MeetCardRow(
                            meet: meet,
                            raceCount: vm.totalRaceCount(for: meet),
                            completedCount: vm.completedRaceCount(for: meet),
                            status: vm.meetStatus(for: meet)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
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
                        if meet.isArchived {
                            Button {
                                vm.unarchive(meet: meet)
                            } label: {
                                Label("Unarchive", systemImage: "tray.and.arrow.up")
                            }
                        } else {
                            Button {
                                vm.archive(meet: meet)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: \u{2013} Add Meet Sheet

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
                        newlyCreatedMeet = meet
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

    // MARK: \u{2013} Edit Meet Sheet

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
}
