import SwiftUI

struct ResultsCardView: View {
    let vm: ResultsViewModel

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            if vm.race.eventType.isRelay {
                relayResults
            } else {
                individualResults
            }
            cardFooter
        }
        .frame(width: 390)
        .background(Color(.systemBackground))
    }

    // MARK: – Header

    private var cardHeader: some View {
        VStack(spacing: 6) {
            Text("RUNSMITH SPLIT TIMER")
                .font(.caption2.weight(.heavy))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            Text(vm.race.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text(vm.race.eventType.displayName)
                if let date = vm.race.startedAt {
                    Text("·").opacity(0.6)
                    Text(Self.dateFormatter.string(from: date))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))
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
            ForEach(Array(vm.rankedAthletes.enumerated()), id: \.element.athlete.id) { i, entry in
                individualRow(entry: entry)
                if i < vm.rankedAthletes.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func individualRow(entry: (athlete: Athlete, place: Int?)) -> some View {
        let finalVal = vm.totalTimeValue(athlete: entry.athlete)
        return HStack(spacing: 12) {
            // Place medal / number
            ZStack {
                if let place = entry.place, place <= 3 {
                    Circle()
                        .fill(medalColor(place))
                        .frame(width: 26, height: 26)
                    Text("\(place)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                } else {
                    Text(entry.place.map { "\($0)" } ?? "—")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26)
                }
            }
            .frame(width: 26)

            Circle()
                .fill(Color(hex: entry.athlete.colorHex))
                .frame(width: 10, height: 10)

            Text(entry.athlete.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(finalVal.displayString)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(entry.place != nil ? .primary : .tertiary)
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ForEach(Array(vm.relayLegData.enumerated()), id: \.element.leg) { i, entry in
                relayRow(entry: entry)
                if i < vm.relayLegData.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }

            if let total = vm.totalRelayMs {
                Divider()
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(total.formattedSplitTime)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(width: 74, alignment: .trailing)
                    Color.clear.frame(width: 72)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
            }
        }
        .padding(.vertical, 6)
    }

    private func relayRow(entry: (leg: Int, athlete: Athlete, legMs: Int?, cumulativeMs: Int?)) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.leg)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            Circle()
                .fill(Color(hex: entry.athlete.colorHex))
                .frame(width: 10, height: 10)

            Text(entry.athlete.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(entry.legMs.map { $0.formattedSplitTime } ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 74, alignment: .trailing)

            Text(entry.cumulativeMs.map { $0.formattedSplitTime } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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
            Text("runsmith.app")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
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
