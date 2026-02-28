import SwiftUI

/// A narrow vertical bar using the athlete's color hex.
struct ColorBar: View {
    let hex: String

    var body: some View {
        Color(hex: hex)
            .frame(width: Theme.colorBarWidth)
            .clipShape(RoundedRectangle(cornerRadius: Theme.colorBarWidth / 2))
    }
}
