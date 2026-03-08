import SwiftUI

struct MeetsTabView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    @State private var showAddMeet = false
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if vm.meets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Meets Yet")
                            .font(.headline)
                        Text("Tap + to create your first meet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(vm.meets) { meet in
                        NavigationLink(value: meet) {
                            MeetRowView(
                                meet: meet,
                                raceCount: vm.meetRaces[meet.id]?.count ?? 0,
                                status: vm.meetStatus(for: meet)
                            )
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
            .listStyle(.insetGrouped)
            .background(Theme.screenBackground)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
            .navigationTitle("Meets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddMeet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
}
