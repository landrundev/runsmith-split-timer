import SwiftUI

struct HeroMeetCard: View {
    let meet: Meet
    let status: RaceStatus
    let completedCount: Int
    let totalCount: Int
    let hasInProgressRace: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    // MARK: \u{2013} Computed

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

    private var isMeetDay: Bool {
        Calendar.current.isDateInToday(meet.date)
    }

    private var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var ctaLabel: String {
        if hasInProgressRace { return "Resume Race" }
        if completedCount >= totalCount && totalCount > 0 { return "View Results" }
        return "Start Next Race"
    }

    private var ctaIcon: String {
        if hasInProgressRace { return "play.fill" }
        if completedCount >= totalCount && totalCount > 0 { return "checkmark.circle" }
        return "play.fill"
    }

    // MARK: \u{2013} Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row \u{2013} label + badge
            HStack {
                if hasInProgressRace {
                    liveBadge
                } else {
                    Label("Next Meet", systemImage: "flag.checkered")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentPrimary)
                }

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
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)

            // Progress bar (only when meet has races)
            if totalCount > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Race progress")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("\(completedCount) of \(totalCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.textMuted.opacity(0.3))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.accentPrimary)
                                .frame(width: max(6, geo.size.width * progressFraction), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            // CTA button
            HStack(spacing: 6) {
                Image(systemName: ctaIcon)
                    .font(.subheadline.weight(.semibold))
                Text(ctaLabel)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Theme.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: \u{2013} LIVE Badge

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.red.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: \u{2013} No Meet Placeholder Card

struct NoMeetCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(Theme.textTertiary)

            Text("No Upcoming Meets")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Create a meet to get started")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.textMuted.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
