import SwiftUI

@main
struct SplitDeckApp: App {
    let store = SplitDeckStore()
    let cache = RaceStateCache()

    @State private var appearance: AppearanceSetting = .current
    @State private var pendingFileURL: URL? = nil

    var body: some Scene {
        WindowGroup {
            MainTabView(
                appearance: $appearance,
                pendingFileURL: $pendingFileURL
            )
            .environmentObject(store)
            .environmentObject(cache)
            .preferredColorScheme(appearance.colorScheme)
            .onChange(of: appearance) { newValue in
                AppearanceSetting.current = newValue
            }
            .onOpenURL { url in
                if url.pathExtension.lowercased() == "runsmith" {
                    pendingFileURL = url
                }
            }
        }
    }
}
