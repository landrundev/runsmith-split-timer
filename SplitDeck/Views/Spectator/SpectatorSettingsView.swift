import SwiftUI

struct SpectatorSettingsView: View {
    @EnvironmentObject var store: SplitDeckStore
    @Environment(\.dismiss) private var dismiss

    @State private var children: [AppSettings.SpectatorChild] = AppSettings.myChildren
    @State private var showAddAthlete = false
    @State private var showSwitchConfirm = false

    @AppStorage("paceUnit") private var paceUnit: String = PaceUnit.perMile.rawValue
    @AppStorage("runsmith_appearance") private var appearanceRaw: String = AppearanceSetting.system.rawValue

    var body: some View {
        NavigationStack {
            List {
                // MY ATHLETES
                Section {
                    ForEach(Array(children.enumerated()), id: \.element.id) { i, child in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: athleteColor(for: child.id)))
                                .frame(width: 8, height: 8)
                            TextField("Name", text: Binding(
                                get: { children[i].displayName },
                                set: { children[i].displayName = $0 }
                            ))
                            .onSubmit {
                                AppSettings.updateChild(children[i])
                            }
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        let idsToRemove = offsets.map { children[$0].id }
                        for id in idsToRemove {
                            AppSettings.removeChild(id: id)
                        }
                        children = AppSettings.myChildren
                    }

                    Button("+ Add athlete") {
                        showAddAthlete = true
                    }
                    .foregroundStyle(Theme.runsmithPink)
                } header: {
                    Text("My Athletes")
                } footer: {
                    Text("Removing an athlete here keeps their race history. To fully delete, use Coach Mode.")
                }

                // PREFERENCES
                Section {
                    Picker(selection: $paceUnit) {
                        ForEach(PaceUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    } label: {
                        Label("Pace Unit", systemImage: "speedometer")
                    }

                    Picker(selection: $appearanceRaw) {
                        ForEach(AppearanceSetting.allCases) { setting in
                            Label(setting.displayName, systemImage: setting.icon)
                                .tag(setting.rawValue)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                } header: {
                    Text("Preferences")
                }

                // SWITCH MODE
                Section {
                    Button {
                        showSwitchConfirm = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Switch to Coach Mode")
                                    .font(.subheadline.weight(.semibold))
                                Text("Meets, rosters, analytics, multi-coach sync")
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

                // ABOUT
                Section {
                    NavigationLink("About Runsmith") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddAthlete, onDismiss: {
                children = AppSettings.myChildren
            }) {
                SpectatorSetupView(mode: .addAthlete)
            }
            .actionSheet(isPresented: $showSwitchConfirm) {
                ActionSheet(
                    title: Text("Switch to Coach Mode?"),
                    message: Text("Your athletes and race history are kept. Switch back anytime in Settings."),
                    buttons: [
                        .default(Text("Switch to Coach Mode")) {
                            AppSettings.appMode = .coach
                        },
                        .cancel()
                    ]
                )
            }
            .onAppear {
                children = AppSettings.myChildren
            }
        }
    }

    private func athleteColor(for id: UUID) -> String {
        if let athletes = try? store.fetchAthletes(),
           let athlete = athletes.first(where: { $0.id == id }) {
            return athlete.colorHex
        }
        return "#888888"
    }
}
