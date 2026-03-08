import SwiftUI

struct MeetCardRow: View {
    let meet: Meet
    var raceCount: Int = 0
    var status: RaceStatus = .notStarted

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Calendar icon badge
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accentPrimary)
            }
            .frame(width: 36, height: 36)
            .background(Theme.accentBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Meet info
            VStack(alignment: .leading, spacing: 3) {
                Text(meet.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(Self.dateFormatter.string(from: meet.date))
                    if let loc = meet.location {
                        Text("\u{00B7}")
                        Text(loc)
                    }
                    if raceCount > 0 {
                        Text("\u{00B7}")
                        Text("\(raceCount) race\(raceCount == 1 ? "" : "s")")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            }

            Spacer()

            // Status pill
            Text(status.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.statusColor(status).opacity(0.12))
                .foregroundStyle(Theme.statusColor(status))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
