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
                    Text("·").opacity(0.6)
                    Text(meetName)
                }
                if let date = data.startedAt {
                    Text("·").opacity(0.6)
                    Text(Self.dateFormatter.string(from: date))
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))

            if !data.isRelay {
                Text(data.displayModeName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
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
