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

    // MARK: – Gender Colors
    static func genderColor(_ gender: Gender?) -> Color {
        switch gender {
        case .male:   return .blue
        case .female: return Color(hex: "#FF5CA1")
        case nil:     return Color(.quaternaryLabel)
        }
    }

    /// Tint for gender toggle buttons: M=blue, F=pink
    static func genderTint(_ gender: Gender) -> Color {
        switch gender {
        case .male:   return .blue
        case .female: return Color(hex: "#FF5CA1")
        }
    }

    // MARK: – Status Badge Colors
    static func statusColor(_ status: RaceStatus) -> Color {
        switch status {
        case .notStarted: return .secondary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

// MARK: – Glassmorphism Button Styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.runsmithPink
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                    // Inner glass highlight
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    // Subtle edge highlight
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                }
            }
            .shadow(color: color.opacity(0.4), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1.0) : 0.4)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.runsmithPink.opacity(0.35))
                    // Inner glass highlight
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    // Edge highlight
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1.0) : 0.4)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func glassActionBar() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 0.5)
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
