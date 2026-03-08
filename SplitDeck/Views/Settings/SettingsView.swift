import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache
    @Binding var appearance: AppearanceSetting

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
                NavigationLink {
                    RelayBuilderView(
                        vm: RelayBuilderViewModel(store: store)
                    )
                } label: {
                    Label("Relay Builder", systemImage: "arrow.triangle.branch")
                }

                NavigationLink {
                    ArchiveView(vm: ArchiveViewModel(store: store))
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } header: {
                Text("Tools")
            }

            // MARK: – About
            Section {
                NavigationLink {
                    AboutView()
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
    }
}
