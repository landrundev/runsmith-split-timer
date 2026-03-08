import SwiftUI

@main
struct SplitDeckApp: App {
    let store = SplitDeckStore()
    let cache = RaceStateCache()

    @State private var appearance: AppearanceSetting = .current

    var body: some Scene {
        WindowGroup {
            MainTabView(appearance: $appearance)
                .environmentObject(store)
                .environmentObject(cache)
                .preferredColorScheme(appearance.colorScheme)
                .onChange(of: appearance) { newValue in
                    AppearanceSetting.current = newValue
                }
        }
    }
}
