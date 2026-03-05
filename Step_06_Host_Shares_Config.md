# Step 06 — Add "Share with Coaches" to Race Setup (Host Shares Config)

**Depends on**: Steps 01–05 must be complete (`CoachIdentity.swift`, `SharedRaceConfig.swift`, `CoachSplitPayload.swift`, `PayloadEncoder.swift`, `QRScannerView.swift`).

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
                // MARK: — Coach + Race Info
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

                // MARK: — QR Code
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

                // MARK: — Action Buttons
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

    // MARK: — QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // Scale up for crisp rendering at 220×220 pt display size
        let scale = 220.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: — Temp File for ShareLink

    private func writeToTemporaryFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}
```

---

## MODIFY `SplitDeck/ViewModels/RaceSetupViewModel.swift`

Add the following function to `RaceSetupViewModel`. Place it **before the final closing brace** of the class, after the existing `startRace()` function:

### Before

```swift
    // MARK: — Start Race

    func startRace() -> Race? {
```

### After

```swift
    // MARK: — Multi-Coach Sharing

    /// Assembles the current race setup state into a SharedRaceConfig
    /// that assistant coaches can import on their devices.
    func buildSharedConfig() -> SharedRaceConfig {
        let orderedIds: [UUID]
        if eventType.isRelay {
            orderedIds = relayAthleteOrder
        } else {
            orderedIds = availableAthletes
                .filter { selectedAthleteIds.contains($0.id) }
                .map(\.id)
        }

        let selectedAthletes = orderedIds.compactMap { id in
            availableAthletes.first { $0.id == id }
        }

        let trackLength: Int
        if eventType.isRelay {
            trackLength = eventType.legDistanceMeters ?? 400
        } else {
            trackLength = 400
        }

        return SharedRaceConfig(
            version: 1,
            configId: UUID(),
            hostCoachName: CoachIdentity.name ?? "Host",
            raceName: raceName.isEmpty ? eventType.displayName : raceName,
            eventType: eventType,
            distanceMeters: unlimitedSplits ? 0 : distanceMeters,
            trackLengthMeters: trackLength,
            splitsPerLap: (eventType.isRelay || unlimitedSplits) ? 1 : splitsPerLap,
            isUnlimitedSplits: unlimitedSplits,
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

    // MARK: — Start Race

    func startRace() -> Race? {
```

---

## MODIFY `SplitDeck/Views/RaceSetup/RaceSetupView.swift`

### Change 1 — Add state variable

Find the block of `@State` declarations at the top of `RaceSetupView`. Add `showShareConfig` alongside the existing relay builder navigation state:

#### Before

```swift
    // Relay builder navigation
    @State private var navigateToRelayBuilder = false
```

#### After

```swift
    // Relay builder navigation
    @State private var navigateToRelayBuilder = false

    // Multi-Coach sharing
    @State private var showShareConfig = false
```

### Change 2 — Add Multi-Coach section to the Form

Find the `eventSection` and `athleteSection` inside the `Form` in the body. Add a new `Section("Multi-Coach")` **after** the `athleteSection`:

#### Before

```swift
            Form {
                eventSection
                athleteSection
            }
```

#### After

```swift
            Form {
                eventSection
                athleteSection

                Section("Multi-Coach") {
                    Button {
                        showShareConfig = true
                    } label: {
                        Label("Share with Coaches", systemImage: "person.2.wave.2")
                    }
                    .disabled(!vm.isValid)
                }
            }
```

### Change 3 — Add sheet modifier

Find the existing `.sheet(isPresented: $showAddAthlete)` modifier on the `NavigationStack`. Add the share config sheet alongside it:

#### Before

```swift
            .sheet(isPresented: $showAddAthlete) {
                addAthleteSheet
            }
```

#### After

```swift
            .sheet(isPresented: $showShareConfig) {
                ShareRaceConfigView(config: vm.buildSharedConfig())
            }
            .sheet(isPresented: $showAddAthlete) {
                addAthleteSheet
            }
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `RaceSetupViewModel.buildSharedConfig()` compiles; calling it returns a `SharedRaceConfig` with the correct `raceName`, `eventType`, and `athletes`
- [ ] Race Setup screen shows a "Multi-Coach" section with a "Share with Coaches" row (person.2.wave.2 icon)
- [ ] The "Share with Coaches" button is disabled until the race setup is valid (at least 1 athlete selected for individual, 4 for relay)
- [ ] Tapping "Share with Coaches" presents `ShareRaceConfigView` as a sheet
- [ ] `ShareRaceConfigView` shows "Sharing as: [coach name from UserDefaults, or 'Host']"
- [ ] `ShareRaceConfigView` shows the race name and athlete count
- [ ] A QR code is rendered in the sheet (non-empty, visible black-and-white pattern)
- [ ] Tapping "Copy QR String" puts a non-empty string on the clipboard and briefly shows "Copied!"
- [ ] Tapping "Share File" opens the system share sheet with a `race-config.json` file
- [ ] Tapping "Done" dismisses the sheet and returns to Race Setup
- [ ] If no athletes are selected, the "Share with Coaches" button is disabled (no crash)
