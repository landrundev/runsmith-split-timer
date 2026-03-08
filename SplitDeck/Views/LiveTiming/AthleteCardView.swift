import SwiftUI

struct AthleteCardView: View {
    let athlete: Athlete
    let splitTimes: [(label: String, cumulative: String, lap: String)]
    let lapProgress: String
    let isComplete: Bool
    let finishTime: String?  // e.g. "4:32.18" \u{2013} total time for completed athlete
    let onTap: () -> Void

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
    // Finish time is the hero \u{2013} own row, full width for splits below.

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

                // Finish time \u{2013} the most important number on the card
                if let time = finishTime {
                    Text(time)
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                }
            }

            // Row 2: split chips \u{2013} full width, nothing competing
            if !splitTimes.isEmpty {
                splitChips
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
                splitChips
            }
        }
    }

    // MARK: \u{2013} Split Chips

    private var splitChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(splitTimes.enumerated()), id: \.offset) { i, split in
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
                        .id(i)
                    }
                }
            }
            .onChange(of: splitTimes.count) { _ in
                withAnimation {
                    proxy.scrollTo(splitTimes.count - 1, anchor: .trailing)
                }
            }
        }
    }
}
