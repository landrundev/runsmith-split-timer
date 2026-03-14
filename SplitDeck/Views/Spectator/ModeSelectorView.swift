import SwiftUI

struct ModeSelectorView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image("RunsmithLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                Text("Split Timer")
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 60)

            Spacer()

            Text("How will you use Split Timer?")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer().frame(minHeight: 16)

            // Coach card
            Button {
                AppSettings.appMode = .coach
            } label: {
                modeCard(
                    icon: "stopwatch.fill",
                    title: "I'm a Coach",
                    detail: "Multi-athlete timing, meets, relay builder, multi-coach sync, and season analytics."
                )
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 12)

            // Spectator card
            Button {
                AppSettings.appMode = .spectator
            } label: {
                modeCard(
                    icon: "heart.fill",
                    title: "I'm a Parent or Fan",
                    detail: "Time my athlete, track personal records across every race, and share results."
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("You can switch modes at any time in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .background(Theme.screenBackground.ignoresSafeArea())
    }

    private func modeCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(Theme.runsmithPink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
