import SwiftUI

// MARK: – Plain data for offscreen rendering (no ObservableObject)

struct CardData {
    let raceName: String
    let eventDisplayName: String
    let startedAt: Date?
    let meetName: String?
    let displayModeName: String   // "Cumulative" or "Lap Times"
    let isRelay: Bool
    let athletes: [CardAthlete]
    let columnLabels: [String]   // e.g. ["400m", "800m", "1200m", "1600m"]
    let relayLegs: [CardRelayLeg]
    let totalRelayTime: String?
    let isMerged: Bool

    // Spectator race details
    let heat: String?
    let overallPlace: Int?
    let heatPlace: Int?
    let isOfficiallyTimed: Bool
    let officialFinalTime: String?   // pre-formatted, e.g. "4:48.93"

    struct CardAthlete {
        let name: String
        let colorHex: String
        let place: Int?
        let totalTime: String
        let splitTimes: [String]  // cumulative split display strings
    }

    struct CardRelayLeg {
        let leg: Int
        let athleteName: String
        let colorHex: String
        let legTime: String
        let cumulativeTime: String
        let intermediateSplits: [(label: String, time: String)]
    }
}

struct ResultsCardView: View {
    let data: CardData

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            if data.isRelay {
                relayResults
            } else {
                individualResults
            }
            cardFooter
        }
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
    }

    // MARK: – Header

    private var cardHeader: some View {
        VStack(spacing: 6) {
            Text("RUNSMITH SPLIT TIMER")
                .font(.caption2.weight(.heavy))
                .tracking(2)
                .foregroundColor(.white.opacity(0.75))

            Text(data.raceName)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text(data.eventDisplayName)
                if let meetName = data.meetName {
                    Text("\u{00B7}").opacity(0.6)
                    Text(meetName)
                }
                if let date = data.startedAt {
                    Text("\u{00B7}").opacity(0.6)
                    Text(Self.dateFormatter.string(from: date))
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))

            // Heat + Placement line
            if data.heat != nil || data.overallPlace != nil || data.heatPlace != nil {
                HStack(spacing: 6) {
                    if let heat = data.heat {
                        Text(heat)
                    }
                    if let op = data.overallPlace {
                        if data.heat != nil { Text("\u{00B7}").opacity(0.6) }
                        HStack(spacing: 3) {
                            if op >= 1, op <= 3 {
                                Image(systemName: "medal.fill")
                                    .foregroundColor(cardMedalColor(op))
                            }
                            Text(cardOrdinal(op) + " overall")
                        }
                    }
                    if let hp = data.heatPlace {
                        Text("\u{00B7}").opacity(0.6)
                        Text(cardOrdinal(hp) + " in heat")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
            }

            // Official time badge
            if data.isOfficiallyTimed, let time = data.officialFinalTime {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Official \u{00B7} \(time)")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
            }

            if !data.isRelay {
                Text(data.displayModeName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            if data.isMerged {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("WA Official")
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.runsmithPink, Theme.runsmithPink.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func cardMedalColor(_ place: Int) -> Color {
        switch place {
        case 1: return Color(hex: "#D4AF37")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .white
        }
    }

    private func cardOrdinal(_ n: Int) -> String {
        let ones = n % 10
        let tens = (n / 10) % 10
        let suffix: String
        if tens == 1 { suffix = "th" }
        else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    // MARK: – Individual Results

    private var individualResults: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.athletes.enumerated()), id: \.offset) { i, athlete in
                individualRow(athlete: athlete)
                if i < data.athletes.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func individualRow(athlete: CardData.CardAthlete) -> some View {
        HStack(spacing: 12) {
            // Place medal / number
            ZStack {
                if let place = athlete.place, place <= 3 {
                    Circle()
                        .fill(medalColor(place))
                        .frame(width: 26, height: 26)
                    Text("\(place)")
                        .font(.caption.weight(.black))
                        .foregroundColor(.white)
                } else {
                    Text(athlete.place.map { "\($0)" } ?? "—")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 26)
                }
            }
            .frame(width: 26)

            Circle()
                .fill(Color(hex: athlete.colorHex))
                .frame(width: 10, height: 10)

            Text(athlete.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(athlete.totalTime)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(athlete.place != nil ? .primary : Color(.tertiaryLabel))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
    }

    // MARK: – Relay Results

    private var relayResults: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("Leg").frame(width: 36, alignment: .leading)
                Text("Athlete")
                Spacer()
                Text("Leg Time").frame(width: 74, alignment: .trailing)
                Text("Cumul.").frame(width: 72, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ForEach(Array(data.relayLegs.enumerated()), id: \.offset) { i, leg in
                relayRow(leg: leg)
                if i < data.relayLegs.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }

            if let total = data.totalRelayTime {
                Divider()
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(total)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(width: 74, alignment: .trailing)
                    Color.clear.frame(width: 72)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .padding(.vertical, 6)
    }

    private func relayRow(leg: CardData.CardRelayLeg) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(leg.leg)")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)

                Circle()
                    .fill(Color(hex: leg.colorHex))
                    .frame(width: 10, height: 10)

                Text(leg.athleteName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text(leg.legTime)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 74, alignment: .trailing)

                Text(leg.cumulativeTime)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)

            // Intermediate split times
            if !leg.intermediateSplits.isEmpty {
                HStack(spacing: 16) {
                    Spacer().frame(width: 36)
                    ForEach(Array(leg.intermediateSplits.enumerated()), id: \.offset) { _, split in
                        VStack(spacing: 0) {
                            Text(split.label)
                                .font(.system(size: 9))
                                .foregroundColor(Color(.tertiaryLabel))
                            Text(split.time)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: – Footer

    private var cardFooter: some View {
        HStack {
            Rectangle()
                .fill(Theme.runsmithPink)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
        }
        .overlay(
            Text("runsmith.com")
                .font(.caption2.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.runsmithPink)
                .clipShape(Capsule()),
            alignment: .center
        )
    }

    // MARK: – Helpers

    private func medalColor(_ place: Int) -> Color {
        switch place {
        case 1: return Color(hex: "#D4AF37")
        case 2: return Color(hex: "#9E9E9E")
        case 3: return Color(hex: "#A0522D")
        default: return .secondary
        }
    }
}
