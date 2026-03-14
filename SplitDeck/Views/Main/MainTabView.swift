import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting
    @Binding var pendingFileURL: URL?

    @State private var selectedTab: Tab = .home
    @State private var showQuickRaceSetup = false
    @State private var showImportRace = false

    /// Single shared ViewModel — both Home and Meets tabs observe the same data.
    @State private var homeVM: HomeViewModel?

    // File auto-open state
    @State private var tabBarHidden = false

    @State private var pendingMeetPayload: CoachMeetPayload? = nil
    @State private var showBulkMergeForFile = false
    @State private var showImportRaceForFile = false

    enum Tab: Int {
        case home, meets, add, roster, analytics
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                if let vm = homeVM {
                    switch selectedTab {
                    case .home:
                        HomeView(
                            vm: vm,
                            appearance: $appearance,
                            selectedTab: $selectedTab
                        )
                    case .meets:
                        MeetsTabView(vm: vm)
                    case .add:
                        Color.clear
                    case .roster:
                        NavigationStack {
                            AthleteRosterView(store: store)
                        }
                    case .analytics:
                        NavigationStack {
                            AnalyticsView(store: store)
                        }
                    }
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar — hidden when a detail view is pushed
            if !tabBarHidden {
                customTabBar
            }
        }
        .environment(\.tabBarHidden, $tabBarHidden)
        .onChange(of: selectedTab) { _ in
            tabBarHidden = false
        }
        .adaptiveSheet(isPresented: $showQuickRaceSetup, onDismiss: { homeVM?.load() }) {
            RaceSetupView(
                vm: RaceSetupViewModel(meetId: nil, store: store),
                store: store,
                cache: cache
            )
        }
        .adaptiveSheet(isPresented: $showImportRace, onDismiss: { homeVM?.load() }) {
            ImportRaceView(store: store)
        }
        .adaptiveSheet(isPresented: $showBulkMergeForFile, onDismiss: {
            pendingMeetPayload = nil
            homeVM?.load()
        }) {
            if let payload = pendingMeetPayload {
                if let meet = findMeet(id: payload.meetId) {
                    BulkMergeView(
                        vm: MeetDetailViewModel(meet: meet, store: store),
                        store: store,
                        preloadedPayload: payload
                    )
                } else {
                    BulkMergeFileErrorView(
                        meetName: payload.meetName,
                        onDismiss: { showBulkMergeForFile = false }
                    )
                }
            }
        }
        .adaptiveSheet(isPresented: $showImportRaceForFile, onDismiss: {
            homeVM?.load()
        }) {
            ImportRaceView(store: store)
        }
        .onAppear {
            if homeVM == nil {
                homeVM = HomeViewModel(store: store)
            }
        }
        .onChange(of: pendingFileURL) { newValue in
            guard let url = newValue else { return }
            pendingFileURL = nil

            // Read the file data
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }

            // Detect content type and route to the right screen
            if let meetPayload = PayloadEncoder.decodeMeetPayload(from: data),
               !meetPayload.racePayloads.isEmpty {
                // Timing data — route to BulkMergeView
                pendingMeetPayload = meetPayload
                selectedTab = .meets
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showBulkMergeForFile = true
                }
            } else if PayloadEncoder.decodeMeetConfig(from: data) != nil
                        || PayloadEncoder.decodeRaceConfig(from: data) != nil {
                // Race/Meet config — route to ImportRaceView
                selectedTab = .home
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showImportRaceForFile = true
                }
            }
            // Unknown content — ignore silently
        }
    }

    // MARK: – Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: "house.fill", label: "Home")
            tabButton(.meets, icon: "calendar", label: "Meets")
            fabButton
            tabButton(.roster, icon: "person.2.fill", label: "Roster")
            tabButton(.analytics, icon: "chart.xyaxis.line", label: "Analytics")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: 0.5)
                }
        }
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            if selectedTab == tab {
                return
            }
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? Theme.runsmithPink : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: – FAB (tap = new race, long-press = menu)

    private var fabButton: some View {
        Menu {
            Button {
                showQuickRaceSetup = true
            } label: {
                Label("New Quick Race", systemImage: "stopwatch.fill")
            }

            Button {
                showImportRace = true
            } label: {
                Label("Import Race / Meet", systemImage: "square.and.arrow.down")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.runsmithPink)
                    .frame(width: 52, height: 52)
                    .shadow(color: Theme.runsmithPink.opacity(0.4), radius: 8, y: 2)

                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: -8)
        } primaryAction: {
            showQuickRaceSetup = true
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Helpers

    private func findMeet(id: UUID) -> Meet? {
        if let vm = homeVM, let meet = vm.meets.first(where: { $0.id == id }) {
            return meet
        }
        if let vm = homeVM, let meet = vm.archivedMeets.first(where: { $0.id == id }) {
            return meet
        }
        return nil
    }
}
