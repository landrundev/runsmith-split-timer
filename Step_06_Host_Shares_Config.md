# Step 06 â Add "Share with Coaches" to Race Setup (Host Shares Config)

**Depends on**: Steps 01â05 must be complete (`CoachIdentity.swift`, `SharedRaceConfig.swift`, `CoachSplitPayload.swift`, `PayloadEncoder.swift`, `QRScannerView.swift`).

---

## CREATE `SplitDeck/Views/Merge/ShareRaceConfigView.swift`

```swift
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Shown when the host taps "Share with Coaches" in Race Setup.
/// Displays a QR code and share/copy options for the SharedRaceConfig.
struct ShareRaceConfigView: View {
    let config: SharedRaceConfig

    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var copyConfirmed = false

    private var qrString: String {
        PayloadEncoder.encodeForQR(config) ?? ""
    }

    private var athleteSummary: String {
        let count = config.athletes.count
        return "\(count) athlete\(count == 1 ? "" : "s")"
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: â Coach + Race Info
                Section {
                    HStack {
                        Label("Sharing as", systemImage: "person.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(config.hostCoachName)
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        Label("Race", systemImage: "flag.checkered")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(config.raceName)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Athletes", systemImage: "person.3")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(athleteSummary)
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Race Info")
                }

                // MARK: â QR Code
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
                    Text("Scan to Import Race")
                } footer: {
                    Text("Assistant coaches scan this code to receive the race setup on their device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: â Action Buttons
                Section {
                    // Share JSON file via system share sheet
                    if let jsonData = PayloadEncoder.encodeJSON(config),
                       let url = writeToTemporaryFile(data: jsonData, filename: "race-config.json") {
                        ShareLink(item: url, preview: SharePreview(config.raceName, icon: Image(systemName: "flag.checkered"))) {
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
            .listStyle(.insetGrouped)
            .navigationTitle("Share with Coaches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                qrImage = generateQRCode(from: qrString)
            }
        }
    }

    // MARK: â QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // Scale up for crisp rendering at 220Ã220 pt display size
        let scale = 220.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: â Temp File for ShareLink

    private func writeToTemporaryFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}
```

---

## MODIFY `SplitDeck/ViewModels/RaceSetupViewModel.swift`

Add the following function to `RaceSetupViewModel`. Place it after any existing race-creation functions (before the final closing brace of the class):

### Before

```swift
    // MARK: â Race Creation
```

### After

```swift
    // MARK: â Race Creation

    /// Assembles the current race setup state into a SharedRaceConfig
    /// that assistant coaches can import on their devices.
    func buildSharedConfig() -> SharedRaceConfig {
        SharedRaceConfig(
            version: 1,
            configId: UUID(),
            hostCoachName: CoachIdentity.name ?? "Host",
            raceName: raceName,
            eventType: selectedEventType,
            distanceMeters: distanceMeters,
            trackLengthMeters: trackLengthMeters,
            splitsPerLap: splitsPerLap,
            isUnlimitedSplits: isUnlimitedSplits,
            athletes: selectedAthletes.map { athlete in
                SharedAthlete(
                    id: athlete.id,
                    name: athlete.name,
                    gender: athlete.gender,
                    colorHex: athlete.colorHex
                )
            }
        )
    }
```

---

## MODIFY `SplitDeck/Views/RaceSetup/RaceSetupView.swift`

### Change 1 â Add state variable

Find the block of `@State` declarations at the top of `RaceSetupView`. Add `showShareConfig` alongside them:

#### Before

```swift
    @State private var showStartConfirmation = false
```

#### After

```swift
    @State private var showStartConfirmation = false
    @State private var showShareConfig = false
```

### Change 2 â Add Multi-Coach section

Find the `Section` containing the Start Race button (look for `"Start Race"` button or `.borderedProminent`). Add the new `Section("Multi-Coach")` immediately **before** the Start button's section:

#### Before

```swift
            Section {
                Button {
                    showStartConfirmation = true
                } label: {
                    Text("Start Race")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)
            }
```

#### After

```swift
            Section("Multi-Coach") {
                Button {
                    showShareConfig = true
                } label: {
                    Label("Share with Coaches", systemImage: "person.2.wave.2")
                }
            }

            Section {
                Button {
                    showStartConfirmation = true
                } label: {
                    Text("Start Race")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)
            }
```

### Change 3 â Add sheet modifier

Find the existing `.sheet` or `.alert` modifiers on the root `List` or `NavigationStack` in `RaceSetupView`. Add the `showShareConfig` sheet alongside them:

#### Before

```swift
            .alert("Start Race?", isPresented: $showStartConfirmation) {
```

#### After

```swift
            .sheet(isPresented: $showShareConfig) {
                ShareRaceConfigView(config: vm.buildSharedConfig())
            }
            .alert("Start Race?", isPresented: $showStartConfirmation) {
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `RaceSetupViewModel.buildSharedConfig()` compiles; calling it returns a `SharedRaceConfig` with the correct `raceName`, `eventType`, and `athletes`
- [ ] Race Setup screen shows a "Multi-Coach" section with a "Share with Coaches" row (person.2.wave.2 icon)
- [ ] Tapping "Share with Coaches" presents `ShareRaceConfigView` as a sheet
- [ ] `ShareRaceConfigView` shows "Sharing as: [coach name from UserDefaults, or 'Host']"
- [ ] `ShareRaceConfigView` shows the race name and athlete count
- [ ] A QR code is rendered in the sheet (non-empty, visible black-and-white pattern)
- [ ] Tapping "Copy QR String" puts a non-empty string on the clipboard and briefly shows "Copied!"
- [ ] Tapping "Share File" opens the system share sheet with a `race-config.json` file
- [ ] Tapping "Done" dismisses the sheet and returns to Race Setup
- [ ] If no athletes are selected, `buildSharedConfig()` returns an empty athletes array (no crash)
