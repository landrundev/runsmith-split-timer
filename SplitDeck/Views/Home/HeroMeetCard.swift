import SwiftUI

struct HeroMeetCard: View {
    let meet: Meet
    let raceCount: Int
    let status: RaceStatus

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private var daysAwayText: String? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfMeet = calendar.startOfDay(for: meet.date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfMeet).day ?? 0
        if days < 0 { return nil }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row — label + countdown
            HStack {
                Label("Next Meet", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentPrimary)

                Spacer()

                if let daysText = daysAwayText {
                    Text(daysText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accentBackground)
                        .clipShape(Capsule())
                }
            }

            // Meet name
            Text(meet.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            // Details row
            HStack(spacing: 12) {
                Label(Self.dateFormatter.string(from: meet.date), systemImage: "calendar")
                if let loc = meet.location {
                    Label(loc, systemImage: "mappin")
                }
                if raceCount > 0 {
                    Label("\(raceCount) race\(raceCount == 1 ? "" : "s")", systemImage: "stopwatch")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)

            // Status bar
            HStack {
                Text(status.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.statusColor(status).opacity(0.12))
                    .foregroundStyle(Theme.statusColor(status))
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.accentPrimary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
