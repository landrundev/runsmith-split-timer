import SwiftUI

struct MeetCardRow: View {
    let meet: Meet
    var raceCount: Int = 0
    var completedCount: Int = 0
    var status: RaceStatus = .notStarted

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Stacked date badge \u{2013} month on top, day below
            VStack(spacing: 0) {
                Text(Self.monthFormatter.string(from: meet.date).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accentPrimary)
                Text(Self.dayFormatter.string(from: meet.date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 44, height: 44)
            .background(Theme.accentBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Meet info
            VStack(alignment: .leading, spacing: 3) {
                Text(meet.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let loc = meet.location {
                        Text(loc)
                        Text("\u{00B7}")
                    }
                    if raceCount > 0 {
                        Text("\(completedCount)/\(raceCount) done")
                    } else {
                        Text("No races")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            }

            Spacer()

            // Status pill
            statusPill
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: \u{2013} Status Pill

    @ViewBuilder
    private var statusPill: some View {
        if status == .inProgress {
            // LIVE badge
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12))
            .clipShape(Capsule())
        } else {
            Text(status.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.statusColor(status).opacity(0.12))
                .foregroundStyle(Theme.statusColor(status))
                .clipShape(Capsule())
        }
    }
}
