import UIKit

/// Draws the share card image using Core Graphics — no SwiftUI rendering pipeline.
enum CardRenderer {

    private static let cardWidth: CGFloat = 390
    private static let pinkColor = UIColor(red: 232/255, green: 24/255, blue: 93/255, alpha: 1) // #E8185D
    private static let goldColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
    private static let silverColor = UIColor(red: 158/255, green: 158/255, blue: 158/255, alpha: 1)
    private static let bronzeColor = UIColor(red: 160/255, green: 82/255, blue: 45/255, alpha: 1)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func render(data: CardData) -> UIImage {
        // Calculate total height
        let hasExtraLines = data.meetName != nil || !data.isRelay
        let headerHeight: CGFloat = hasExtraLines ? 140 : 116
        let nameRowHeight: CGFloat = 40
        let splitsRowHeight: CGFloat = 32
        let footerHeight: CGFloat = 28
        let leftPad: CGFloat = 20

        let hasSplits = !data.columnLabels.isEmpty

        let contentHeight: CGFloat
        if data.isRelay {
            let rows = data.relayLegs.count + 1 + (data.totalRelayTime != nil ? 1 : 0)
            contentHeight = CGFloat(max(rows, 1)) * nameRowHeight + 12
        } else {
            var h: CGFloat = 12
            for _ in data.athletes {
                h += nameRowHeight
                if hasSplits { h += splitsRowHeight }
            }
            contentHeight = h
        }
        let totalHeight = headerHeight + contentHeight + footerHeight

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: cardWidth, height: totalHeight),
            format: format
        )

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // White background
            UIColor.white.setFill()
            cgCtx.fill(CGRect(x: 0, y: 0, width: cardWidth, height: totalHeight))

            // Draw header with logo
            var y = drawHeader(ctx: cgCtx, data: data, height: headerHeight)

            // Draw content
            if data.isRelay {
                y = drawRelayContent(ctx: cgCtx, data: data, y: y, rowHeight: nameRowHeight, leftPad: leftPad)
            } else {
                y = drawIndividualContent(ctx: cgCtx, data: data, y: y,
                                          nameRowHeight: nameRowHeight,
                                          splitsRowHeight: splitsRowHeight,
                                          leftPad: leftPad)
            }

            // Draw footer
            drawFooter(ctx: cgCtx, y: totalHeight - footerHeight, width: cardWidth, height: footerHeight)
        }
    }

    // MARK: – Header (with logo)

    private static func drawHeader(ctx: CGContext, data: CardData, height: CGFloat) -> CGFloat {
        // Pink gradient background
        let gradientColors = [pinkColor.cgColor, pinkColor.withAlphaComponent(0.75).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: gradientColors as CFArray,
                                  locations: [0, 1])!
        ctx.saveGState()
        ctx.addRect(CGRect(x: 0, y: 0, width: cardWidth, height: height))
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                               start: .zero,
                               end: CGPoint(x: cardWidth, y: height),
                               options: [])
        ctx.restoreGState()

        // Runsmith logo (from asset catalog)
        var cursorY: CGFloat = 18
        if let logo = UIImage(named: "RunsmithLogo") {
            let logoHeight: CGFloat = 28
            let logoWidth = logo.size.width / logo.size.height * logoHeight
            let logoRect = CGRect(x: (cardWidth - logoWidth) / 2, y: cursorY, width: logoWidth, height: logoHeight)
            logo.withTintColor(.white, renderingMode: .alwaysTemplate).draw(in: logoRect)
            cursorY += logoHeight + 10
        } else {
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.75),
                .kern: 2.0
            ]
            let subtitle = "RUNSMITH SPLIT TIMER"
            let subtitleSize = (subtitle as NSString).size(withAttributes: subtitleAttrs)
            (subtitle as NSString).draw(
                at: CGPoint(x: (cardWidth - subtitleSize.width) / 2, y: cursorY),
                withAttributes: subtitleAttrs
            )
            cursorY += subtitleSize.height + 10
        }

        // Race name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let nameSize = (data.raceName as NSString).size(withAttributes: nameAttrs)
        (data.raceName as NSString).draw(
            at: CGPoint(x: (cardWidth - nameSize.width) / 2, y: cursorY),
            withAttributes: nameAttrs
        )
        cursorY += nameSize.height + 6

        // Info line: meet + date (skip event type — it's already in the race name)
        var infoParts: [String] = []
        if let meetName = data.meetName {
            infoParts.append(meetName)
        }
        if let date = data.startedAt {
            infoParts.append(dateFormatter.string(from: date))
        }
        if !infoParts.isEmpty {
            let infoText = infoParts.joined(separator: "  ·  ")
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let infoSize = (infoText as NSString).size(withAttributes: infoAttrs)
            (infoText as NSString).draw(
                at: CGPoint(x: (cardWidth - infoSize.width) / 2, y: cursorY),
                withAttributes: infoAttrs
            )
            cursorY += infoSize.height + 4
        }

        // Display mode label (e.g. "Cumulative" / "Lap Times")
        if !data.isRelay {
            let modeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            let modeSize = (data.displayModeName as NSString).size(withAttributes: modeAttrs)
            (data.displayModeName as NSString).draw(
                at: CGPoint(x: (cardWidth - modeSize.width) / 2, y: cursorY),
                withAttributes: modeAttrs
            )
        }

        return height
    }

    // MARK: – Individual Results (with splits)

    private static func drawIndividualContent(
        ctx: CGContext, data: CardData, y: CGFloat,
        nameRowHeight: CGFloat, splitsRowHeight: CGFloat, leftPad: CGFloat
    ) -> CGFloat {
        var currentY = y + 6
        let hasSplits = !data.columnLabels.isEmpty

        for (i, athlete) in data.athletes.enumerated() {
            // — Name row —
            let rowY = currentY

            // Medal or place number
            if let place = athlete.place, place <= 3 {
                let medalColor = place == 1 ? goldColor : (place == 2 ? silverColor : bronzeColor)
                medalColor.setFill()
                let circleRect = CGRect(x: leftPad, y: rowY + (nameRowHeight - 26) / 2, width: 26, height: 26)
                ctx.fillEllipse(in: circleRect)

                let placeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .black),
                    .foregroundColor: UIColor.white
                ]
                let placeStr = "\(place)"
                let placeSize = (placeStr as NSString).size(withAttributes: placeAttrs)
                (placeStr as NSString).draw(
                    at: CGPoint(x: circleRect.midX - placeSize.width / 2,
                                y: circleRect.midY - placeSize.height / 2),
                    withAttributes: placeAttrs
                )
            } else {
                let placeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let placeStr = athlete.place.map { "\($0)" } ?? "—"
                let placeSize = (placeStr as NSString).size(withAttributes: placeAttrs)
                (placeStr as NSString).draw(
                    at: CGPoint(x: leftPad + 13 - placeSize.width / 2,
                                y: rowY + (nameRowHeight - placeSize.height) / 2),
                    withAttributes: placeAttrs
                )
            }

            // Color dot
            let dotX: CGFloat = leftPad + 38
            UIColor(hexString: athlete.colorHex).setFill()
            ctx.fillEllipse(in: CGRect(x: dotX, y: rowY + (nameRowHeight - 10) / 2, width: 10, height: 10))

            // Name
            let nameX: CGFloat = dotX + 22
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            (athlete.name as NSString).draw(
                at: CGPoint(x: nameX, y: rowY + (nameRowHeight - 18) / 2),
                withAttributes: nameAttrs
            )

            // Total time (right-aligned)
            let timeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: athlete.place != nil ? UIColor.label : UIColor.tertiaryLabel
            ]
            let timeSize = (athlete.totalTime as NSString).size(withAttributes: timeAttrs)
            (athlete.totalTime as NSString).draw(
                at: CGPoint(x: cardWidth - leftPad - timeSize.width,
                            y: rowY + (nameRowHeight - timeSize.height) / 2),
                withAttributes: timeAttrs
            )

            currentY += nameRowHeight

            // — Splits row —
            if hasSplits && !athlete.splitTimes.isEmpty {
                let colCount = data.columnLabels.count
                let colWidth = (cardWidth - leftPad * 2) / CGFloat(colCount)

                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.label
                ]

                for (col, label) in data.columnLabels.enumerated() {
                    let colX = leftPad + CGFloat(col) * colWidth
                    let colCenter = colX + colWidth / 2

                    // Label
                    let labelSize = (label as NSString).size(withAttributes: labelAttrs)
                    (label as NSString).draw(
                        at: CGPoint(x: colCenter - labelSize.width / 2, y: currentY),
                        withAttributes: labelAttrs
                    )

                    // Value
                    if col < athlete.splitTimes.count {
                        let val = athlete.splitTimes[col]
                        let valSize = (val as NSString).size(withAttributes: valueAttrs)
                        (val as NSString).draw(
                            at: CGPoint(x: colCenter - valSize.width / 2, y: currentY + 14),
                            withAttributes: valueAttrs
                        )
                    }
                }
                currentY += splitsRowHeight
            }

            // Divider
            if i < data.athletes.count - 1 {
                UIColor.separator.setFill()
                ctx.fill(CGRect(x: leftPad, y: currentY - 0.5, width: cardWidth - leftPad * 2, height: 0.5))
            }
        }

        return currentY + 6
    }

    // MARK: – Relay Results

    private static func drawRelayContent(ctx: CGContext, data: CardData, y: CGFloat, rowHeight: CGFloat, leftPad: CGFloat) -> CGFloat {
        var currentY = y + 6

        // Column headers
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        ("Leg" as NSString).draw(at: CGPoint(x: leftPad, y: currentY + 12), withAttributes: headerAttrs)
        ("Athlete" as NSString).draw(at: CGPoint(x: leftPad + 50, y: currentY + 12), withAttributes: headerAttrs)

        let legTimeLabel = "Leg Time"
        let legTimeLabelSize = (legTimeLabel as NSString).size(withAttributes: headerAttrs)
        (legTimeLabel as NSString).draw(
            at: CGPoint(x: cardWidth - leftPad - 72 - 10 - legTimeLabelSize.width, y: currentY + 12),
            withAttributes: headerAttrs
        )

        let cumulLabel = "Cumul."
        let cumulLabelSize = (cumulLabel as NSString).size(withAttributes: headerAttrs)
        (cumulLabel as NSString).draw(
            at: CGPoint(x: cardWidth - leftPad - cumulLabelSize.width, y: currentY + 12),
            withAttributes: headerAttrs
        )

        currentY += rowHeight
        UIColor.separator.setFill()
        ctx.fill(CGRect(x: leftPad, y: currentY - 0.5, width: cardWidth - leftPad * 2, height: 0.5))

        // Leg rows
        for (i, leg) in data.relayLegs.enumerated() {
            let rowY = currentY

            let legAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.secondaryLabel
            ]
            ("\(leg.leg)" as NSString).draw(
                at: CGPoint(x: leftPad, y: rowY + (rowHeight - 16) / 2),
                withAttributes: legAttrs
            )

            UIColor(hexString: leg.colorHex).setFill()
            ctx.fillEllipse(in: CGRect(x: leftPad + 40, y: rowY + (rowHeight - 10) / 2, width: 10, height: 10))

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            (leg.athleteName as NSString).draw(
                at: CGPoint(x: leftPad + 60, y: rowY + (rowHeight - 16) / 2),
                withAttributes: nameAttrs
            )

            let legTimeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let ltSize = (leg.legTime as NSString).size(withAttributes: legTimeAttrs)
            (leg.legTime as NSString).draw(
                at: CGPoint(x: cardWidth - leftPad - 72 - 10 - ltSize.width,
                            y: rowY + (rowHeight - ltSize.height) / 2),
                withAttributes: legTimeAttrs
            )

            let cumulAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let ctSize = (leg.cumulativeTime as NSString).size(withAttributes: cumulAttrs)
            (leg.cumulativeTime as NSString).draw(
                at: CGPoint(x: cardWidth - leftPad - ctSize.width,
                            y: rowY + (rowHeight - ctSize.height) / 2),
                withAttributes: cumulAttrs
            )

            currentY += rowHeight
            if i < data.relayLegs.count - 1 {
                UIColor.separator.setFill()
                ctx.fill(CGRect(x: leftPad + 56, y: currentY - 0.5, width: cardWidth - leftPad - 56 - leftPad, height: 0.5))
            }
        }

        // Total row
        if let total = data.totalRelayTime {
            UIColor.separator.setFill()
            ctx.fill(CGRect(x: leftPad, y: currentY - 0.5, width: cardWidth - leftPad * 2, height: 0.5))

            UIColor.secondarySystemBackground.setFill()
            ctx.fill(CGRect(x: 0, y: currentY, width: cardWidth, height: rowHeight))

            let totalLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            ("Total" as NSString).draw(
                at: CGPoint(x: leftPad, y: currentY + (rowHeight - 16) / 2),
                withAttributes: totalLabelAttrs
            )

            let totalTimeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let ttSize = (total as NSString).size(withAttributes: totalTimeAttrs)
            (total as NSString).draw(
                at: CGPoint(x: cardWidth - leftPad - 72 - 10 - ttSize.width,
                            y: currentY + (rowHeight - ttSize.height) / 2),
                withAttributes: totalTimeAttrs
            )
            currentY += rowHeight
        }

        return currentY + 6
    }

    // MARK: – Footer

    private static func drawFooter(ctx: CGContext, y: CGFloat, width: CGFloat, height: CGFloat) {
        // Pink bar
        pinkColor.setFill()
        ctx.fill(CGRect(x: 0, y: y + height / 2 - 1.5, width: width, height: 3))

        // Capsule badge
        let badgeText = "runsmith.com"
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        let badgeSize = (badgeText as NSString).size(withAttributes: badgeAttrs)
        let badgePadH: CGFloat = 10
        let badgePadV: CGFloat = 4
        let badgeRect = CGRect(
            x: (width - badgeSize.width - badgePadH * 2) / 2,
            y: y + (height - badgeSize.height - badgePadV * 2) / 2,
            width: badgeSize.width + badgePadH * 2,
            height: badgeSize.height + badgePadV * 2
        )
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeRect.height / 2)
        pinkColor.setFill()
        badgePath.fill()

        (badgeText as NSString).draw(
            at: CGPoint(x: badgeRect.origin.x + badgePadH, y: badgeRect.origin.y + badgePadV),
            withAttributes: badgeAttrs
        )
    }
}

// MARK: – UIColor hex helper

private extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (128, 128, 128)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
