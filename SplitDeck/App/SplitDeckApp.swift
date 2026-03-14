import SwiftUI

@main
struct SplitDeckApp: App {
    let store = SplitDeckStore()
    let cache = RaceStateCache()

    @AppStorage("runsmith_appMode") private var appModeRaw: String = ""
    @State private var appearance: AppearanceSetting = .current
    @State private var pendingFileURL: URL? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                switch AppSettings.AppMode(rawValue: appModeRaw) {

                case .coach:
                    MainTabView(
                        appearance: $appearance,
                        pendingFileURL: $pendingFileURL
                    )
                    .preferredColorScheme(appearance.colorScheme)
                    .onChange(of: appearance) { newValue in
                        AppearanceSetting.current = newValue
                    }
                    .onOpenURL { url in
                        if url.pathExtension.lowercased() == "runsmith" {
                            pendingFileURL = url
                        }
                    }

                case .spectator:
                    SpectatorRootView()
                        .preferredColorScheme(appearance.colorScheme)

                case nil:
                    ModeSelectorView()
                }
            }
            .environmentObject(store)
            .environmentObject(cache)
        }
    }
}
