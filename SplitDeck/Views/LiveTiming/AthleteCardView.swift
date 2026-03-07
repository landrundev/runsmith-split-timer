import SwiftUI

struct AthleteCardView: View {
    let athlete: Athlete
    let splitTimes: [(label: String, cumulative: String, lap: String)]
    let lapProgress: String
    let isComplete: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Theme.genderColor(athlete.gender)
                    .frame(width: Theme.colorBarWidth)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.colorBarWidth / 2))
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 10, height: 10)
                        Text(athlete.name)
                            .font(.headline)
                            .foregroundStyle(isComplete ? .secondary : .primary)
                        Spacer()
                        Text(lapProgress)
                            .font(.caption)
                            .foregroundStyle(isComplete ? .green : .secondary)
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .imageScale(.large)
                        }
                    }

                    if splitTimes.isEmpty {
                        Text("No splits recorded")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        splitChips
                    }
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
