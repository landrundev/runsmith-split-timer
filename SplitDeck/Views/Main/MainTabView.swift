import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting

    @State private var selectedTab: Tab = .home
    @State private var showQuickRaceSetup = false

    enum Tab: Int {
        case home, meets, add, roster, analytics
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .home:
                    HomeView(vm: HomeViewModel(store: store), appearance: $appearance)
                case .meets:
                    MeetsTabView(vm: HomeViewModel(store: store))
                case .add:
                    // Placeholder — the (+) button triggers a sheet, not a tab
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            customTabBar
        }
        .sheet(isPresented: $showQuickRaceSetup) {
            RaceSetupView(
                vm: RaceSetupViewModel(meetId: nil, store: store),
                store: store,
                cache: cache
            )
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

    private var fabButton: some View {
        Button {
            showQuickRaceSetup = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.runsmithPink)
                    .frame(width: 52, height: 52)
                    .shadow(color: Theme.runsmithPink.opacity(0.4), radius: 8, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: -8)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
