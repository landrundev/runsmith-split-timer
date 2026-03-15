import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting
    @AppStorage("paceUnit") private var paceUnit: String = PaceUnit.perMile.rawValue
    @State private var showSwitchToFan = false

    var body: some View {
        List {
            // MARK: – Appearance
            Section {
                Picker(selection: $appearance) {
                    ForEach(AppearanceSetting.allCases) { setting in
                        Label(setting.displayName, systemImage: setting.icon)
                            .tag(setting)
                    }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
            } header: {
                Text("Display")
            }

            // MARK: – Tools
            Section {
                Picker(selection: $paceUnit) {
                    ForEach(PaceUnit.allCases, id: \.rawValue) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                } label: {
                    Label("Pace Unit", systemImage: "speedometer")
                }

                NavigationLink {
                    ImportRaceView(store: store)
                        .hidesTabBar()
                } label: {
                    Label("Import Race / Meet", systemImage: "square.and.arrow.down")
                }

                NavigationLink {
                    RelayBuilderView(
                        vm: RelayBuilderViewModel(store: store)
                    )
                    .hidesTabBar()
                } label: {
                    Label("Relay Builder", systemImage: "arrow.triangle.branch")
                }

                NavigationLink {
                    ArchiveView(vm: ArchiveViewModel(store: store))
                        .hidesTabBar()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } header: {
                Text("Tools")
            }

            // MARK: – Switch Mode
            Section {
                Button {
                    showSwitchToFan = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch to Fan Mode")
                                .font(.subheadline.weight(.semibold))
                            Text("Time your own athlete and track their PRs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }

            // MARK: – About
            Section {
                NavigationLink {
                    AboutView()
                        .hidesTabBar()
                } label: {
                    HStack(spacing: 12) {
                        Image("RunsmithLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("About Runsmith")
                                .font(.body)
                            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "28"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .actionSheet(isPresented: $showSwitchToFan) {
            ActionSheet(
                title: Text("Switch to Fan Mode?"),
                message: Text("Your meets, rosters, and race history are kept. Switch back anytime."),
                buttons: [
                    .default(Text("Switch to Fan Mode")) {
                        AppSettings.appMode = .spectator
                    },
                    .cancel()
                ]
            )
        }
    }
}
