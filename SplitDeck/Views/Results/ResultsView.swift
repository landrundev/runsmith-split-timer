import SwiftUI

struct ResultsView: View {
    @ObservedObject var vm: ResultsViewModel
    @EnvironmentObject var store: SplitDeckStore
    var onDone: (() -> Void)? = nil
    @State private var previewImage: UIImage? = nil
    @State private var showExport = false
    @State private var showMerge = false
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            raceInfoHeader
            TipCardView(
                tipId: "coachMerge",
                icon: "person.2.badge.gearshape",
                message: "Tap the \u{00B7}\u{00B7}\u{00B7} menu to share or merge splits. Use Export for Merge to send your splits to a head coach via QR code. Use Merge Coach Data if you\u{2019}re the head coach combining splits from assistants."
            )

            Picker("Display", selection: $vm.displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            if vm.race.eventType.isRelay {
                relayResultsTable
            } else {
                resultsTable
            }
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onDone != nil)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        let data = vm.buildCardData()
                        previewImage = CardRenderer.render(data: data)
                    } label: {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showExport = true
                    } label: {
                        Label("Export for Merge", systemImage: "arrow.up.doc")
                    }

                    Button {
                        showMerge = true
                    } label: {
                        Label("Merge Coach Data", systemImage: "person.2.badge.gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if onDone != nil {
                doneButton
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSplitsView(payload: vm.buildCoachSplitPayload())
        }
        .sheet(isPresented: $showMerge) {
            MergeView(vm: MergeViewModel(
                race: vm.race,
                athletes: vm.orderedAthletes,
                hostSplits: vm.splits,
                store: store
            ))
        }
        .sheet(item: Binding(
            get: { previewImage.map { SharePreviewItem(image: $0) } },
            set: { if $0 == nil { previewImage = nil } }
        )) { item in
            SharePreviewSheet(image: item.image, csvURL: vm.csvFileURL())
        }
    }

    // MARK: – Race Info Header

    private var raceInfoHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.race.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Text(vm.race.eventType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                if let meet = vm.meet {
                    Text("\u{00B7}").foregroundStyle(Theme.textTertiary)
                    Text(meet.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                if let date = vm.race.startedAt {
                    Text("\u{00B7}").foregroundStyle(Theme.textTertiary)
                    Text(Self.dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if vm.race.isMerged {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("WA Official")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
    }

    // MARK: – Done Button (bottom)

    private var doneButton: some View {
        Button {
            onDone?()
            dismiss()
        } label: {
            Text("Done")
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .glassActionBar()
    }

    // MARK: – Individual Results Table

    private var resultsTable: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(vm.rankedAthletes, id: \.athlete.id) { entry in
                    athleteBlock(entry: entry)
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func athleteBlock(entry: (athlete: Athlete, place: Int?)) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Theme.genderColor(entry.athlete.gender))
                .frame(width: 4)
                .clipShape(Capsule())
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 8) {

                // Name + total time row (always full width, no scroll)
                HStack(spacing: 6) {
                    Text(entry.place.map { "\($0)" } ?? "\u{2014}")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, alignment: .leading)

                    Circle()
                        .fill(Color(hex: entry.athlete.colorHex))
                        .frame(width: 10, height: 10)

                    Text(entry.athlete.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    let finalVal = vm.totalTimeValue(athlete: entry.athlete)
                    if case .missing = finalVal, entry.place == nil {
                        Text("DNF")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                    } else {
                        Text(finalVal.displayString)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(entry.place != nil ? Theme.textPrimary : Theme.textTertiary)
                    }
                }

                // Split columns — wrapping rows (max 4 per row)
                if !vm.columnLabels.isEmpty {
                    wrappingSplitColumns(athlete: entry.athlete, labels: vm.columnLabels)
                }
            }
        }
        .padding(.vertical, 12)
    }

    /// Max columns per row before wrapping.
    private static let columnsPerRow = 4

    /// Splits column indices into balanced rows of ≤ columnsPerRow.
    private func splitColumnRows(count: Int) -> [[Int]] {
        guard count > 0 else { return [] }

        let maxPerRow = Self.columnsPerRow
        if count <= maxPerRow { return [Array(0..<count)] }

        let rowCount = (count + maxPerRow - 1) / maxPerRow
        let basePerRow = count / rowCount
        let remainder = count % rowCount

        var rows: [[Int]] = []
        var idx = 0
        for r in 0..<rowCount {
            let cols = basePerRow + (r < remainder ? 1 : 0)
            rows.append(Array(idx..<(idx + cols)))
            idx += cols
        }
        return rows
    }

    /// Renders wrapping split columns for one athlete (max 4 per row, balanced).
    private func wrappingSplitColumns(athlete: Athlete, labels: [String]) -> some View {
        let rows = splitColumnRows(count: labels.count)

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(labels[i])
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            let val = vm.cellValue(athlete: athlete, splitOrdinal: i + 1)
                            Text(val.displayString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: – Relay Results Table

    private var relayResultsTable: some View {
        let hasIntermediates = vm.race.splitsPerLap > 1

        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("Leg")
                        .frame(width: 36, alignment: .leading)
                    Text("Athlete")
                    Spacer()
                    Text(vm.displayMode == .cumulative ? "Cumulative" : "Leg Time")
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(Array(vm.relayLegData.enumerated()), id: \.element.leg) { i, entry in
                    VStack(spacing: 0) {
                        // Main leg row
                        HStack(spacing: 8) {
                            Text("\(entry.leg)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 36, alignment: .leading)

                            Circle()
                                .fill(Color(hex: entry.athlete.colorHex))
                                .frame(width: 10, height: 10)

                            Text(entry.athlete.firstName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if vm.displayMode == .cumulative {
                                Text(entry.cumulativeMs.map { $0.formattedSplitTime } ?? "\u{2014}")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 90, alignment: .trailing)
                            } else {
                                Text(entry.legMs.map { $0.formattedSplitTime } ?? "\u{2014}")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Intermediate split sub-row (when enabled)
                        if hasIntermediates {
                            let details = RaceDomain.relayLegIntermediateSplits(
                                legIndex: i,
                                athletes: vm.orderedAthletes,
                                splits: vm.splits,
                                race: vm.race
                            )
                            if !details.isEmpty {
                                HStack(alignment: .bottom, spacing: 12) {
                                    Spacer()
                                        .frame(width: 36)
                                    ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                                        VStack(spacing: 1) {
                                            Text(detail.label)
                                                .font(.system(size: 10))
                                                .foregroundStyle(Theme.textTertiary)
                                            Text(detail.lapMs.formattedSplitTime)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    if vm.displayMode == .cumulative {
                                        Text("(\(entry.legMs.map { $0.formattedSplitTime } ?? "\u{2014}"))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                        }
                    }

                    Divider()
                }

                // Total row
                if let total = vm.totalRelayMs {
                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(total.formattedSplitTime)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.cardBackground)
                }
            }
        }
    }
}

// MARK: – Share Preview

private struct SharePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct SharePreviewSheet: View {
    let image: UIImage
    let csvURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var savedToPhotos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Share Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        withAnimation { savedToPhotos = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedToPhotos = false }
                        }
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save",
                              systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                    }
                    Button {
                        var items: [Any] = [image]
                        if let url = csvURL { items.append(url) }
                        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = scene.windows.first?.rootViewController {
                            var topVC = rootVC
                            while let presented = topVC.presentedViewController { topVC = presented }
                            avc.popoverPresentationController?.barButtonItem = nil
                            topVC.present(avc, animated: true)
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
