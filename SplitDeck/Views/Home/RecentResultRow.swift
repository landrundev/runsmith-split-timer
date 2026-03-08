import SwiftUI

struct RecentResultRow: View {
    let result: HomeViewModel.RecentResult
    let athletes: [Athlete]

    private var genderFill: AnyShapeStyle {
        let genders = athletes
            .filter { result.gender == nil ? true : $0.gender == result.gender }
            .map { $0.gender }
        let hasMale = genders.contains(.male) || result.gender == .male
        let hasFemale = genders.contains(.female) || result.gender == .female

        if hasMale && hasFemale {
            return AnyShapeStyle(LinearGradient(
                colors: [Theme.genderMale, Theme.genderFemale],
                startPoint: .top, endPoint: .bottom
            ))
        } else if hasMale {
            return AnyShapeStyle(Theme.genderMale)
        } else if hasFemale {
            return AnyShapeStyle(Theme.genderFemale)
        } else {
            return AnyShapeStyle(Theme.textMuted)
        }
    }

    private var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(result.completedAt) { return "Today" }
        if cal.isDateInYesterday(result.completedAt) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: result.completedAt, to: Date()).day ?? 0
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: result.completedAt)
    }

    private var bestTimeString: String? {
        guard let ms = result.bestFinishMs else { return nil }
        let totalSeconds = Double(ms) / 1000.0
        let minutes = Int(totalSeconds) / 60
        let seconds = totalSeconds - Double(minutes * 60)
        if minutes > 0 {
            return String(format: "%d:%05.2f", minutes, seconds)
        } else {
            return String(format: "%.2f", seconds)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Gender accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(genderFill)
                .frame(width: 4, height: 40)

            // Race info
            VStack(alignment: .leading, spacing: 3) {
                Text(result.raceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(result.athleteCount) athlete\(result.athleteCount == 1 ? "" : "s")")
                    Text("\u{00B7}")
                    Text(relativeDate)
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            // Best time
            if let best = bestTimeString {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(best)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("Best")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
