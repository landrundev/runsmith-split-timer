import SwiftUI

@main
struct SplitDeckApp: App {
    let store = SplitDeckStore()
    let cache = RaceStateCache()

    var body: some Scene {
        WindowGroup {
            HomeView(vm: HomeViewModel(store: store))
                .environmentObject(store)
                .environmentObject(cache)
        }
    }
}
