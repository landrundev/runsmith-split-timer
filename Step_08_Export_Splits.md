# Step 08 â Add "Export for Merge" to ResultsView (Assistant Coach Exports Splits)

**Depends on**: Steps 01â07 must be complete (`CoachIdentity.swift`, `SharedRaceConfig.swift`, `CoachSplitPayload.swift`, `PayloadEncoder.swift`, `QRScannerView.swift`, `ShareRaceConfigView.swift`, `ImportRaceView.swift`).

---

## CREATE `SplitDeck/Views/Merge/ExportSplitsView.swift`

```swift
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Shown to assistant coaches after their race ends.
/// Displays a QR code of the CoachSplitPayload that the host coach scans
/// to merge splits together.
struct ExportSplitsView: View {
    let payload: CoachSplitPayload

    @Environment(\.dismiss) private var dismiss

    // MARK: â State

    @State private var coachName: String = CoachIdentity.name ?? ""
    @State private var qrImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var copyConfirmed = false
    @State private var showNamePrompt = false
    @State private var promptName: String = ""

    // MARK: â Computed

    /// Re-encode payload with the current coach name whenever it changes.
    private var currentPayload: CoachSplitPayload {
        CoachSplitPayload(
            version: payload.version,
            configId: payload.configId,
            coachName: coachName.isEmpty ? "Coach" : coachName,
            exportedAt: payload.exportedAt,
            athleteSplits: payload.athleteSplits
        )
    }

    private var qrString: String {
        PayloadEncoder.encodeForQR(currentPayload) ?? ""
    }

    private var athleteCount: Int { payload.athleteSplits.count }

    // MARK: â Body

    var body: some View {
        NavigationStack {
            List {
                coachNameSection
                qrSection
                actionSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export for Merge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if coachName.isEmpty {
                    showNamePrompt = true
                } else {
                    regenerateQR()
                }
            }
            .onChange(of: coachName) { _, _ in
                regenerateQR()
            }
            .alert("Enter Your Name", isPresented: $showNamePrompt) {
                TextField("e.g. Coach Williams", text: $promptName)
                Button("Save") {
                    let trimmed = promptName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        CoachIdentity.name = trimmed
                        coachName = trimmed
                    }
                    regenerateQR()
                }
                Button("Skip") {
                    regenerateQR()
                }
            } message: {
                Text("Your name appears on the host coach's merge screen so they know whose splits you're sharing.")
            }
        }
    }

    // MARK: â Sections

    private var coachNameSection: some View {
        Section {
            HStack {
                TextField("Coach name", text: $coachName)
                    .autocorrectionDisabled()
                if !coachName.isEmpty {
                    Button {
                        CoachIdentity.name = coachName.trimmingCharacters(in: .whitespaces)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.runsmithPink)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Coach Name")
        } footer: {
            Text("Shown on the host's merge screen. Tap â to save for future exports.")
                .font(.caption)
        }
    }

    private var qrSection: some View {
        Section {
            HStack {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                } else {
                    ProgressView()
                        .frame(width: 220, height: 220)
                }
                Spacer()
            }
            .listRowBackground(Color(.systemGroupedBackground))
        } header: {
            Text("QR Code")
        } footer: {
            Text("Scan this code on the host coach's device to merge splits. Contains \(athleteCount) athlete\(athleteCount == 1 ? "" : "s").")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        Section {
            // Share JSON file via system share sheet
            if let jsonData = PayloadEncoder.encodeJSON(currentPayload),
               let url = writeToTemporaryFile(data: jsonData, filename: "splits-\(sanitizedCoachName).json") {
                ShareLink(
                    item: url,
                    preview: SharePreview(
                        "\(coachName.isEmpty ? "Coach" : coachName) â Split Export",
                        icon: Image(systemName: "stopwatch")
                    )
                ) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }

            // Copy QR string to clipboard
            Button {
                UIPasteboard.general.string = qrString
                copyConfirmed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copyConfirmed = false
                }
            } label: {
                Label(
                    copyConfirmed ? "Copied!" : "Copy QR String",
                    systemImage: copyConfirmed ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
                .foregroundStyle(copyConfirmed ? .green : .accentColor)
            }
        }
    }

    // MARK: â Helpers

    private var sanitizedCoachName: String {
        coachName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            .isEmpty ? "export" : coachName
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
    }

    private func regenerateQR() {
        guard !qrString.isEmpty else { return }
        qrImage = generateQRCode(from: qrString)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = 220.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func writeToTemporaryFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}
```

---

## MODIFY `SplitDeck/ViewModels/ResultsViewModel.swift`

Add the following function to `ResultsViewModel`. Place it after the existing results-building functions (before the final closing brace of the class):

### Before

```swift
    // MARK: â Share Card
```

### After

```swift
    // MARK: â Merge Export

    /// Builds a CoachSplitPayload from this ViewModel's current athletes and splits.
    /// Used by ExportSplitsView to generate the assistant coach's shareable QR code.
    func buildCoachSplitPayload() -> CoachSplitPayload {
        let athleteTimingData: [AthleteTimingData] = athletes.map { athlete in
            let sortedSplits = splits
                .filter { $0.athleteId == athlete.id }
                .sorted { $0.lapIndex < $1.lapIndex }
                .map { $0.elapsedMs }
            return AthleteTimingData(
                athleteId: athlete.id,
                splits: sortedSplits
            )
        }
        return CoachSplitPayload(
            version: 1,
            configId: UUID(),
            coachName: CoachIdentity.name ?? "Coach",
            exportedAt: Date(),
            athleteSplits: athleteTimingData
        )
    }

    // MARK: â Share Card
```

---

## MODIFY `SplitDeck/Views/Results/ResultsView.swift`

### Change 1 â Add state variables

Find the block of `@State` declarations in `ResultsView`. Add `showExport` and `showMerge` alongside the existing state:

#### Before

```swift
    @State private var previewImage: UIImage? = nil
```

#### After

```swift
    @State private var previewImage: UIImage? = nil
    @State private var showExport = false
    @State private var showMerge = false
```

### Change 2 â Replace the single Share toolbar button with a Menu

Find the existing toolbar item that contains the Share button in `ResultsView`. It looks similar to:

#### Before

```swift
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let data = vm.buildCardData()
                        previewImage = CardRenderer.render(data: data)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
```

#### After

```swift
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
```

### Change 3 â Add sheet modifiers

Find the existing `.sheet` modifiers on `ResultsView`'s root view (the one used for the share card preview). Add two new sheets alongside the existing one:

#### Before

```swift
        .sheet(isPresented: $showPreview) {
```

#### After

```swift
        .sheet(isPresented: $showExport) {
            ExportSplitsView(payload: vm.buildCoachSplitPayload())
        }
        .sheet(isPresented: $showMerge) {
            Text("Coming soon")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPreview) {
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `ResultsViewModel.buildCoachSplitPayload()` compiles; returns a `CoachSplitPayload` with one `AthleteTimingData` per athlete, splits sorted by `lapIndex`
- [ ] Results screen toolbar now shows `ellipsis.circle` icon instead of `square.and.arrow.up`
- [ ] Tapping `...` reveals a menu with three options: "Share Results", "Export for Merge", "Merge Coach Data"
- [ ] "Share Results" still works exactly as before (generates share card image)
- [ ] "Export for Merge" presents `ExportSplitsView` as a sheet
- [ ] `ExportSplitsView` shows the Coach Name text field, pre-filled from `CoachIdentity.name` if one is saved
- [ ] If no coach name is saved, an alert prompts for entry on appear
- [ ] Entering a name in the text field and tapping â saves it to `CoachIdentity` (persists after dismissing and reopening)
- [ ] A QR code is rendered in the sheet (visible black-and-white pattern)
- [ ] Editing the coach name field regenerates the QR code
- [ ] "Copy QR String" copies a non-empty base64 string to the clipboard and briefly shows "Copied!"
- [ ] "Share File" opens the system share sheet with a `.json` file
- [ ] "Merge Coach Data" shows the "Coming soon" placeholder text
- [ ] Tapping "Done" dismisses `ExportSplitsView`
