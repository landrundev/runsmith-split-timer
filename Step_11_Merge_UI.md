# Step 11 â Create MergeView and Wire into ResultsView

**Depends on**: Steps 01â10 must be complete (`QRScannerView.swift`, `PayloadEncoder.swift`, `MergeViewModel.swift`, `SplitDeckStore.replaceSplits`, `ExportSplitsView.swift`).

---

## CREATE `SplitDeck/Views/Merge/MergeView.swift`

```swift
import SwiftUI
import UniformTypeIdentifiers

/// The host coach's merge screen.
/// Presented as a sheet from ResultsView after the race ends.
/// Lets the host import assistant coach payloads (via QR or file),
/// preview merged splits side-by-side, and commit the final values.
struct MergeView: View {
    @ObservedObject var vm: MergeViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: â Local State

    @State private var showFileImporter = false
    @State private var fileImportError: String? = nil
    @State private var showFileError = false
    @State private var showSaveSuccess = false

    // MARK: â Body

    var body: some View {
        NavigationStack {
            List {
                importedCoachesSection
                strategySection
                if !vm.mergePreview.isEmpty {
                    previewSections
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Merge Coach Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .sheet(isPresented: $vm.showScanner) {
                QRScannerView { scanned in
                    vm.showScanner = false
                    handleScannedString(scanned)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.json, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: $showFileError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(fileImportError ?? "Could not read the file.")
            }
            .alert("Merge Saved", isPresented: $showSaveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Splits have been updated with the merged values.")
            }
            .onChange(of: vm.mergeStrategy) { _, _ in
                vm.computePreview()
            }
        }
    }

    // MARK: â Imported Coaches Section

    private var importedCoachesSection: some View {
        Section {
            Button {
                vm.showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }

            Button {
                showFileImporter = true
            } label: {
                Label("Import File", systemImage: "doc.badge.plus")
            }

            ForEach(Array(vm.importedPayloads.enumerated()), id: \.offset) { index, payload in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payload.coachName)
                            .font(.body)
                        Text("\(payload.athleteSplits.count) athlete\(payload.athleteSplits.count == 1 ? "" : "s") Â· \(formattedDate(payload.exportedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .onDelete { indexSet in
                for index in indexSet.sorted().reversed() {
                    vm.removePayload(at: index)
                }
            }
        } header: {
            Text("Imported Coaches")
        } footer: {
            if vm.importedPayloads.isEmpty {
                Text("Scan each assistant coach's QR code or import their exported file.")
                    .font(.caption)
            }
        }
    }

    // MARK: â Strategy Section

    private var strategySection: some View {
        Section {
            Picker("Strategy", selection: $vm.mergeStrategy) {
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
        }
    }

    // MARK: â Preview Sections (one per athlete)

    @ViewBuilder
    private var previewSections: some View {
        ForEach(vm.mergePreview, id: \.athleteId) { result in
            Section {
                athletePreviewTable(result)
            } header: {
                Text(result.athleteName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
        }
    }

    /// Renders the side-by-side split table for one athlete.
    @ViewBuilder
    private func athletePreviewTable(_ result: SplitMerger.MergedResult) -> some View {
        let splitCount = max(
            result.originalSplits.count,
            result.mergedSplits.count
        )
        guard splitCount > 0 else {
            Text("No splits recorded")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            return
        }

        // Column headers row
        HStack(spacing: 0) {
            Text("Source")
                .frame(width: 90, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(0..<splitCount, id: \.self) { i in
                Text("Split \(i + 1)")
                    .frame(maxWidth: .infinity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .listRowBackground(Color(.systemGroupedBackground))

        // Host row
        splitRow(
            label: "You",
            splits: result.originalSplits,
            splitCount: splitCount,
            flags: [],
            bold: false
        )

        // Each imported coach's row
        ForEach(Array(vm.importedPayloads.enumerated()), id: \.offset) { idx, payload in
            let coachSplits = idx < result.coachSplits.count ? result.coachSplits[idx] : []
            splitRow(
                label: payload.coachName,
                splits: coachSplits,
                splitCount: splitCount,
                flags: result.flags,
                coachIndex: idx + 1,
                bold: false
            )
        }

        Divider()

        // Merged row (bold)
        splitRow(
            label: "Merged",
            splits: result.mergedSplits,
            splitCount: splitCount,
            flags: [],
            bold: true
        )
    }

    /// A single row in the preview table.
    private func splitRow(
        label: String,
        splits: [Int],
        splitCount: Int,
        flags: [SplitMerger.SplitFlag],
        coachIndex: Int = 0,
        bold: Bool
    ) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ForEach(0..<splitCount, id: \.self) { i in
                let ms = i < splits.count ? splits[i] : nil
                let isOutlier: Bool = {
                    guard coachIndex > 0, i < flags.count else { return false }
                    if case .outlier(let ci) = flags[i], ci == coachIndex { return true }
                    return false
                }()

                HStack(spacing: 2) {
                    if isOutlier {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(ms.map { formatElapsedMs($0) } ?? "â")
                        .font(bold ? .subheadline.bold() : .subheadline)
                        .foregroundStyle(isOutlier ? .orange : (bold ? .primary : .secondary))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .listRowBackground(bold ? Color(.systemGray6) : Color(.systemBackground))
    }

    // MARK: â Save Button

    private var saveButton: some View {
        VStack(spacing: 4) {
            Button {
                vm.commitMerge()
                showSaveSuccess = true
            } label: {
                Text("Save Merged Results")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.runsmithPink)
            .disabled(vm.importedPayloads.isEmpty)
            .padding(.horizontal, 16)

            Text("Replaces current splits with merged values.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: â Handlers

    private func handleScannedString(_ string: String) {
        guard let content = PayloadEncoder.decodeQR(string) else { return }
        switch content {
        case .splitPayload(let payload):
            vm.importPayload(payload)
        case .raceConfig:
            // Wrong QR type â silently ignore (this scanner is only for split payloads)
            break
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                fileImportError = "Could not read the file."
                showFileError = true
                return
            }
            if let payload = PayloadEncoder.decodeSplitPayload(from: data) {
                vm.importPayload(payload)
            } else {
                fileImportError = "The file doesn't appear to be a valid Runsmith split export."
                showFileError = true
            }

        case .failure(let error):
            fileImportError = error.localizedDescription
            showFileError = true
        }
    }

    // MARK: â Formatting Helpers

    /// Converts an elapsed time in milliseconds to a display string: "m:ss.xx"
    ///
    /// Examples:
    ///   58410 ms â "0:58.41"
    ///   118650 ms â "1:58.65"
    static func formatElapsedMs(_ ms: Int) -> String {
        let totalTenths = ms / 10          // drop sub-10ms precision
        let hundredths = totalTenths % 100
        let totalSeconds = totalTenths / 100
        let seconds = totalSeconds % 60
        let minutes = totalSeconds / 60
        return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }

    private func formatElapsedMs(_ ms: Int) -> String {
        MergeView.formatElapsedMs(ms)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
```

---

## MODIFY `SplitDeck/Views/Results/ResultsView.swift`

### Change 1 â Add `@EnvironmentObject` for the store

Find the property declarations at the top of `ResultsView`. Add the `store` environment object below the existing `@ObservedObject vm`:

#### Before

```swift
    @ObservedObject var vm: ResultsViewModel
```

#### After

```swift
    @ObservedObject var vm: ResultsViewModel
    @EnvironmentObject var store: SplitDeckStore
```

### Change 2 â Replace the "Coming soon" Merge sheet with MergeView

Find the `.sheet(isPresented: $showMerge)` modifier added in Step 08. Replace its content:

#### Before

```swift
        .sheet(isPresented: $showMerge) {
            Text("Coming soon")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
```

#### After

```swift
        .sheet(isPresented: $showMerge) {
            MergeView(vm: MergeViewModel(
                race: vm.race,
                athletes: vm.athletes,
                hostSplits: vm.splits,
                store: store
            ))
        }
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `ResultsView` compiles with `@EnvironmentObject var store: SplitDeckStore`
- [ ] Tapping "Merge Coach Data" in the Results `...` menu opens `MergeView` as a sheet (no longer shows "Coming soon")
- [ ] `MergeView` shows a "Scan QR Code" button and an "Import File" button
- [ ] Tapping "Scan QR Code" presents `QRScannerView`
- [ ] Scanning a valid `CoachSplitPayload` QR (generated by `ExportSplitsView` in Step 08) adds the coach to the "Imported Coaches" list
- [ ] Scanning the same QR twice does not create a duplicate entry
- [ ] The imported coach row shows the coach name and athlete count
- [ ] Swipe-to-delete removes a coach from the list and recomputes the preview
- [ ] After importing a payload, the preview table appears with one section per athlete
- [ ] Each athlete section shows a "You" row, a row per imported coach, and a bold "Merged" row
- [ ] Split times are displayed as "m:ss.xx" (e.g., "0:58.41" for 58410 ms)
- [ ] Outlier splits are shown with an orange warning triangle icon
- [ ] The Strategy segmented picker switches between "Median" and "Average"; changing it immediately updates the Merged row values
- [ ] The "Save Merged Results" button is disabled until at least one payload is imported
- [ ] Tapping "Save Merged Results" calls `MergeViewModel.commitMerge()`, shows a success alert, then dismisses the sheet
- [ ] After dismissing, `ResultsView` reflects the newly merged split times
- [ ] Tapping "Import File" opens the system file importer; selecting a valid `.json` split export file imports it correctly
- [ ] Selecting an invalid file shows an error alert with a descriptive message
- [ ] `MergeView.formatElapsedMs(58410)` returns `"0:58.41"`
- [ ] `MergeView.formatElapsedMs(118650)` returns `"1:58.65"`
- [ ] `MergeView.formatElapsedMs(3723000)` returns `"62:03.00"` (handles > 60 min races without crashing)
