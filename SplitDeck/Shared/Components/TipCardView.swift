import SwiftUI

/// A contextual tip card that appears once to guide new users.
/// Dismisses permanently when the user taps "Got it".
///
/// Usage:
///     TipCardView(
///         tipId: "markSplit",
///         icon: "hand.tap",
///         message: "Tap MARK SPLIT when a runner crosses..."
///     )
struct TipCardView: View {
    let tipId: String
    let icon: String
    let message: String

    @State private var isVisible: Bool = false

    var body: some View {
        Group {
            if isVisible {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Theme.runsmithPink)
                        .frame(width: 28, alignment: .center)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isVisible = false
                            }
                            TipManager.markShown(tipId)
                        } label: {
                            Text("Got it")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.runsmithPink)
                        }
                    }
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.runsmithPink.opacity(0.25), lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if TipManager.shouldShow(tipId) {
                withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
                    isVisible = true
                }
            }
        }
    }
}
