import SwiftUI

struct MeetRaceCardRow: View {
    let race: Race
    let athletes: [Athlete]

    private var genderFill: AnyShapeStyle {
        let genders = race.athleteIds.compactMap { id in
            athletes.first(where: { $0.id == id })?.gender
        }
        let hasMale = genders.contains(.male)
        let hasFemale = genders.contains(.female)

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

    var body: some View {
        HStack(spacing: 12) {
            // Gender accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(genderFill)
                .frame(width: 4, height: 40)

            // Race info
            VStack(alignment: .leading, spacing: 3) {
                Text(race.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(race.eventType.displayName)
                    if !race.athleteIds.isEmpty {
                        Text("\u{00B7}")
                        Text("\(race.athleteIds.count) athlete\(race.athleteIds.count == 1 ? "" : "s")")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if race.isMerged {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("WA")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
            }

            // Status pill
            Text(race.status.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.statusColor(race.status).opacity(0.12))
                .foregroundStyle(Theme.statusColor(race.status))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
