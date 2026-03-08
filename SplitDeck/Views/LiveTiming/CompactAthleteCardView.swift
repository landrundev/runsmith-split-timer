import SwiftUI

struct CompactAthleteCardView: View {
    let athlete: Athlete
    let lastLapDelta: String?
    let lapProgress: String
    let isComplete: Bool
    let finishTime: String?  // e.g. "4:32.18"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Theme.genderColor(athlete.gender))
                    .frame(width: 4)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 7, height: 7)
                        Text(athlete.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isComplete ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        if isComplete, let time = finishTime {
                            // Total finish time \u{2013} bold pink
                            Text(time)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.accentPrimary)
                        } else if let delta = lastLapDelta {
                            Text(delta)
                                .font(.caption.weight(.semibold).monospacedDigit())
                        } else {
                            Text("\u{2014}")
                                .font(.caption.monospacedDigit())
                        }
                        Spacer(minLength: 0)
                        Text(lapProgress)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
    }
}
