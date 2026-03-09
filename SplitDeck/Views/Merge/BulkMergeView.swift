import SwiftUI
import UniformTypeIdentifiers

/// Host coach flow: import a `.runsmith` file (or QR/clipboard) and merge all races at once.
/// Also used as the auto-open destination when tapping a `.runsmith` file.
struct BulkMergeView: View {
    @ObservedObject var vm: MeetDetailViewModel
    let store: SplitDeckStore

    /// If provided, skip the method picker and go straight to verification.
    var preloadedPayload: CoachMeetPayload? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: — State

    @State private var importedPayload: CoachMeetPayload? = nil
    @State private var matchResults: [MeetDetailViewModel.RaceMatchResult] = []
    @State private var mergeStrategy: SplitMerger.MergeStrategy = .median
    @State private var errorMessage: String? = nil
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var showSuccess = false
    @State private var scannedString: String? = nil
    @State private var mergedCount = 0

    private var matchedCount: Int {
        matchResults.filter { $0.status == .matched }.count
    }

    private var flaggedCount: Int {
        matchResults.filter { $0.status != .matched }.count
    }

    // MARK: — Body

    var body: some View {
        NavigationStack {
            Group {
                if showSuccess {
                    successView
                } else if importedPayload != nil {
                    reviewView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if showScanner {
                    scannerView
                } else {
                    methodPickerView
                }
            }
            .navigationTitle("Merge Coach Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    PayloadEncoder.runsmithType,
                    UTType.json,
                    UTType.data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: scannedString) { newValue in
                guard let scanned = newValue else { return }
                showScanner = false
                processScannedString(scanned)
            }
            .onAppear {
                if let preloaded = preloadedPayload, importedPayload == nil {
                    processPayload(preloaded)
                }
            }
        }
    }

    // MARK: — Step 1: Method Picker

    private var methodPickerView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 48))
                .foregroundStyle(Theme.runsmithPink)

            VStack(spacing: 8) {
                Text("Merge Coach Timing Data")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("Import an assistant coach's .runsmith file to merge split data for all races in this meet at once.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Open .runsmith File", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPrimaryButtonStyle())

                Button {
                    showScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassSecondaryButtonStyle())

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: — Scanner

    private var scannerView: some View {
        QRScannerView { scanned in
            scannedString = scanned
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("Scan the assistant coach's timing data QR code")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 48)
        }
    }

    // MARK: — Step 2: Review + Verify

    private var reviewView: some View {
        List {
            // Coach info
            if let payload = importedPayload {
                Section {
                    row(icon: "person.circle", label: "Coach", value: payload.coachName)
                    row(icon: "calendar", label: "Meet", value: payload.meetName)
                    HStack {
                        Label("Meet Verified", systemImage: "shield")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if store.meetExists(id: payload.meetId) {
                            Label("Found", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Found", systemImage: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    row(icon: "flag.checkered", label: "Races Received", value: "\(payload.racePayloads.count)")
                    HStack {
                        Label("Races Matched", systemImage: "checkmark.circle")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(matchedCount)")
                            .foregroundStyle(matchedCount > 0 ? Theme.runsmithPink : .red)
                            .fontWeight(.semibold)
                    }
                    if flaggedCount > 0 {
                        HStack {
                            Label("Flagged", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(flaggedCount) skipped")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Import Summary")
                }
            }

            // Matched races
            let matched = matchResults.filter { $0.status == .matched }
            if !matched.isEmpty {
                Section {
                    ForEach(matched) { result in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.raceName)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(result.athleteCount) athlete\(result.athleteCount == 1 ? "" : "s") timed")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }
                } header: {
                    Text("Ready to Merge")
                } footer: {
                    Text("These races exist in your meet and have matching timing data from this coach.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // Flagged races
            let flagged = matchResults.filter { $0.status != .matched }
            if !flagged.isEmpty {
                Section {
                    ForEach(flagged) { result in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.raceName)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textMuted)
                                Text(flagReason(result.status))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                        }
                    }
                } header: {
                    Text("Flagged \u{2014} Will Be Skipped")
                } footer: {
                    Text("These races could not be matched to your local data. They may have been set up on a different device without sharing the race config first.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // Merge strategy
            if matchedCount > 0 {
                Section {
                    Picker("Strategy", selection: $mergeStrategy) {
                        ForEach(SplitMerger.MergeStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.rawValue).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Merge Strategy")
                } footer: {
                    Text("Median: ignores outliers (recommended). Average: arithmetic mean of all values.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if matchedCount > 0 {
                VStack(spacing: 4) {
                    Button {
                        mergedCount = matchedCount
                        vm.commitBulkMerge(results: matchResults, strategy: mergeStrategy)
                        showSuccess = true
                    } label: {
                        Text("Merge \(matchedCount) Race\(matchedCount == 1 ? "" : "s")")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .padding(.horizontal, 16)

                    if flaggedCount > 0 {
                        Text("\(flaggedCount) flagged race\(flaggedCount == 1 ? "" : "s") will be skipped.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.bottom, 8)
                    } else {
                        Text("Replaces your splits with merged values for matched races.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.bottom, 8)
                    }
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: — Step 3: Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.runsmithPink)

            VStack(spacing: 8) {
                Text("Merge Complete!")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("\(mergedCount) race\(mergedCount == 1 ? "" : "s") merged successfully")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                if flaggedCount > 0 {
                    Text("\(flaggedCount) race\(flaggedCount == 1 ? " was" : "s were") skipped (flagged)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: — Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                errorMessage = nil
                scannedString = nil
                importedPayload = nil
                matchResults = []
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: — Processing

    private func processPayload(_ payload: CoachMeetPayload) {
        // Cache the imported payload
        store.cacheImportedPayload(payload)

        // Verify all races
        let results = vm.verifyPayload(payload)
        matchResults = results
        importedPayload = payload
    }

    private func processScannedString(_ string: String) {
        guard let content = PayloadEncoder.decodeQR(string) else {
            errorMessage = "This doesn't appear to be valid Runsmith data."
            return
        }

        switch content {
        case .meetPayload(let payload):
            processPayload(payload)
        case .splitPayload(let payload):
            // Single race payload — wrap it
            let meetPayload = CoachMeetPayload(
                version: 1,
                id: UUID(),
                meetId: vm.meet.id,
                meetName: vm.meet.name,
                coachName: payload.coachName,
                exportedAt: payload.exportedAt,
                racePayloads: [
                    RacePayloadEntry(
                        configId: payload.configId,
                        raceId: UUID(),
                        meetId: vm.meet.id,
                        raceName: payload.raceName ?? "Imported Race",
                        athleteSplits: payload.athleteSplits
                    )
                ]
            )
            processPayload(meetPayload)
        case .raceConfig, .meetConfig:
            errorMessage = "This is a race/meet setup config, not timing data. The assistant coach needs to export their split data after timing the races."
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Could not read the file."
                return
            }

            if let payload = PayloadEncoder.decodeMeetPayload(from: data) {
                processPayload(payload)
            } else if let singlePayload = PayloadEncoder.decodeSplitPayload(from: data) {
                // Wrap single race payload
                let meetPayload = CoachMeetPayload(
                    version: 1,
                    id: UUID(),
                    meetId: vm.meet.id,
                    meetName: vm.meet.name,
                    coachName: singlePayload.coachName,
                    exportedAt: singlePayload.exportedAt,
                    racePayloads: [
                        RacePayloadEntry(
                            configId: singlePayload.configId,
                            raceId: UUID(),
                            meetId: vm.meet.id,
                            raceName: singlePayload.raceName ?? "Imported Race",
                            athleteSplits: singlePayload.athleteSplits
                        )
                    ]
                )
                processPayload(meetPayload)
            } else {
                errorMessage = "This file doesn't appear to be a valid Runsmith timing data file (.runsmith)."
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            errorMessage = "Nothing on the clipboard."
            return
        }
        processScannedString(pasted)
    }

    private func flagReason(_ status: MeetDetailViewModel.RaceMatchResult.MatchStatus) -> String {
        switch status {
        case .matched: return ""
        case .meetNotFound: return "Meet not found on this device"
        case .raceNotFound: return "Race not found in this meet"
        }
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
