import SwiftUI

struct AthleteCardView: View {
    let athlete: Athlete
    let splitTimes: [(label: String, cumulative: String, lap: String)]
    let lapProgress: String
    let isComplete: Bool
    let finishTime: String?  // e.g. "4:32.18" \u{2013} total time for completed athlete
    let onTap: () -> Void

    /// Max chips per row before wrapping.
    private static let chipsPerRow = 4

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Theme.genderColor(athlete.gender)
                    .frame(width: Theme.colorBarWidth)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.colorBarWidth / 2))
                    .padding(.trailing, 12)

                if isComplete {
                    completedLayout
                } else {
                    activeLayout
                }

                Spacer(minLength: 0)
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

    // MARK: \u{2013} Completed State

    private var completedLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: name + finish time
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.medium)
                Text(athlete.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let time = finishTime {
                    Text(time)
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                }
            }

            // Row 2+: split chips \u{2013} wrapping rows, no horizontal scroll
            if !splitTimes.isEmpty {
                wrappingSplitChips
            }
        }
    }

    // MARK: \u{2013} Active State (in-progress / waiting)

    private var activeLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: athlete.colorHex))
                    .frame(width: 10, height: 10)
                Text(athlete.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(lapProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if splitTimes.isEmpty {
                Text("No splits recorded")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                wrappingSplitChips
            }
        }
    }

    // MARK: \u{2013} Wrapping Split Chips (multi-row)

    /// Splits the chips into balanced rows of \u{2264} chipsPerRow.
    /// e.g. 8 chips \u{2192} 4 + 4, 6 \u{2192} 3 + 3, 5 \u{2192} 3 + 2, 3 \u{2192} 3
    private var chipRows: [[Int]] {
        let count = splitTimes.count
        guard count > 0 else { return [] }

        let maxPerRow = Self.chipsPerRow
        if count <= maxPerRow { return [Array(0..<count)] }

        let rowCount = (count + maxPerRow - 1) / maxPerRow
        let basePerRow = count / rowCount
        let remainder = count % rowCount

        var rows: [[Int]] = []
        var idx = 0
        for r in 0..<rowCount {
            // Distribute remainder to earlier rows so top row fills first
            let cols = basePerRow + (r < remainder ? 1 : 0)
            rows.append(Array(idx..<(idx + cols)))
            idx += cols
        }
        return rows
    }

    private var wrappingSplitChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chipRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { i in
                        chipView(for: splitTimes[i])
                    }
                }
            }
        }
    }

    private func chipView(for split: (label: String, cumulative: String, lap: String)) -> some View {
        VStack(spacing: 1) {
            Text(split.lap)
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(split.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
