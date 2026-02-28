import SwiftUI

struct AthleteCardView: View {
    let athlete: Athlete
    let lastSplitSummary: String?
    let lapProgress: String
    let isComplete: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ColorBar(hex: athlete.colorHex)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(athlete.name)
                        .font(.headline)
                        .foregroundStyle(isComplete ? .secondary : .primary)

                    Text(lastSplitSummary.map { "Last split: \($0)" } ?? "Last split: —")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(lapProgress)
                        .font(.caption)
                        .foregroundStyle(isComplete ? .green : .secondary)
                }

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.large)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: Theme.athleteCardMinHeight)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
    }
}
