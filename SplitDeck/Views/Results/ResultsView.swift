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
            Divider()

            if vm.race.eventType.isRelay {
                relayResultsTable
            } else {
                Picker("Display", selection: $vm.displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Divider()

                resultsTable
            }
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.race.name)
                .font(.headline)

            HStack(spacing: 6) {
                Text(vm.race.eventType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let meet = vm.meet {
                    Text("·").foregroundStyle(.tertiary)
                    Text(meet.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let date = vm.race.startedAt {
                    Text("·").foregroundStyle(.tertiary)
                    Text(Self.dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
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
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func athleteBlock(entry: (athlete: Athlete, place: Int?)) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.genderColor(entry.athlete.gender))
                .frame(width: 4)
                .clipShape(Capsule())
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 6) {
                    Text(entry.place.map { "\($0)" } ?? "—")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)

                    Circle()
                        .fill(Color(hex: entry.athlete.colorHex))
                        .frame(width: 10, height: 10)

                    Text(entry.athlete.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    let finalVal = vm.totalTimeValue(athlete: entry.athlete)
                    Text(finalVal.displayString)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(entry.place != nil ? .primary : .tertiary)
                }

            if !vm.columnLabels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(vm.columnLabels.enumerated()), id: \.offset) { i, label in
                        VStack(spacing: 2) {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            let val = vm.cellValue(athlete: entry.athlete, splitOrdinal: i + 1)
                            Text(val.displayString)
                                .font(.caption.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: – Relay Results Table

    private var relayResultsTable: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("Leg")
                        .frame(width: 36, alignment: .leading)
                    Text("Athlete")
                    Spacer()
                    Text("Leg Time")
                        .frame(width: 74, alignment: .trailing)
                    Text("Cumulative")
                        .frame(width: 82, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(vm.relayLegData, id: \.leg) { entry in
                    HStack(spacing: 8) {
                        Text("\(entry.leg)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)

                        Circle()
                            .fill(Color(hex: entry.athlete.colorHex))
                            .frame(width: 10, height: 10)

                        Text(entry.athlete.firstName)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text(entry.legMs.map { $0.formattedSplitTime } ?? "—")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 74, alignment: .trailing)

                        Text(entry.cumulativeMs.map { $0.formattedSplitTime } ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 82, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                }

                // Total row
                if let total = vm.totalRelayMs {
                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(total.formattedSplitTime)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .frame(width: 74, alignment: .trailing)
                        Text("")
                            .frame(width: 82)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
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
            .background(Color(.systemGroupedBackground))
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
