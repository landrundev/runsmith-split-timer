import SwiftUI

enum Theme {
    // MARK: – Brand Colors
    static let badgeYellow = Color(hex: "#FFC700")
    static let runsmithPink = Color(hex: "#E8185D")

    // MARK: – Semantic Colors
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)

    // MARK: – Layout
    static let athleteCardMinHeight: CGFloat = 68
    static let markButtonHeight: CGFloat = 64
    static let colorBarWidth: CGFloat = 6
    static let cardCornerRadius: CGFloat = 12

    // MARK: – Status Badge Colors
    static func statusColor(_ status: RaceStatus) -> Color {
        switch status {
        case .notStarted: return .secondary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

// MARK: – Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
