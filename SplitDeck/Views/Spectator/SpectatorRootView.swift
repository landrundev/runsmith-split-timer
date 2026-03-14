import SwiftUI

struct SpectatorRootView: View {
    @EnvironmentObject var store: SplitDeckStore
    @EnvironmentObject var cache: RaceStateCache

    var body: some View {
        NavigationStack {
            SpectatorHomeView()
        }
    }
}
