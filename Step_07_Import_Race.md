# Step 07 â Add "Import Race" to HomeView (Assistant Coach Scans Config)

**Depends on**: Steps 01â06 must be complete (`CoachIdentity.swift`, `SharedRaceConfig.swift`, `CoachSplitPayload.swift`, `PayloadEncoder.swift`, `QRScannerView.swift`, `ShareRaceConfigView.swift`).

---

## CREATE `SplitDeck/Views/Merge/ImportRaceView.swift`

```swift
import SwiftUI

/// Presented to assistant coaches from the Home screen.
/// Scans a SharedRaceConfig QR code, creates athletes + a race in Core Data,
/// then offers a "Start Timing" button to navigate to LiveTimingView.
struct ImportRaceView: View {
    let store: SplitDeckStore

    @Environment(\.dismiss) private var dismiss

    // MARK: â State

    /// The raw string scanned from the QR code.
    @State private var scannedString: String? = nil
    /// The race created in Core Data after a successful import.
    @State private var importedRace: Race? = nil
    /// The decoded config (held so we can show athlete count in the success screen).
    @State private var importedConfig: SharedRaceConfig? = nil
    /// Error message to show if decoding or saving fails.
    @State private var errorMessage: String? = nil
    /// Whether the QR scanner is active (true on first appearance; re-activated on retry).
    @State private var isScanning: Bool = true
    /// Controls navigation to LiveTimingView after import.
    @State private var navigateToTiming: Bool = false

    // MARK: â Body

    var body: some View {
        NavigationStack {
            Group {
                if let race = importedRace, let config = importedConfig {
                    successView(race: race, config: config)
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if isScanning {
                    scannerView
                } else {
                    // Transient state between scan and decode
                    ProgressView("Importing raceâ¦")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Import Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToTiming) {
                if let race = importedRace {
                    LiveTimingView(race: race, store: store)
                }
            }
        }
        .onChange(of: scannedString) { _, newValue in
            guard let scanned = newValue else { return }
            isScanning = false
            processScannedString(scanned)
        }
    }

    // MARK: â Subviews

    private var scannerView: some View {
        QRScannerView { scanned in
            scannedString = scanned
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("Point camera at the host coach's QR code")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 48)
        }
    }

    private func successView(race: Race, config: SharedRaceConfig) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.runsmithPink)

            VStack(spacing: 8) {
                Text("Race Imported!")
                    .font(.title2.bold())

                Text(race.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("\(config.athletes.count) athlete\(config.athletes.count == 1 ? "" : "s") ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button {
                    navigateToTiming = true
                } label: {
                    Text("Start Timing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.title2.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                errorMessage = nil
                scannedString = nil
                isScanning = true
            } label: {
                Label("Scan Again", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.runsmithPink)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: â Logic

    private func processScannedString(_ string: String) {
        guard let content = PayloadEncoder.decodeQR(string) else {
            errorMessage = "This QR code is not a valid Runsmith race config. Make sure you're scanning the code from the host coach's \"Share with Coaches\" screen."
            return
        }

        switch content {
        case .raceConfig(let config):
            do {
                let race = try store.importRace(from: config)
                importedConfig = config
                importedRace = race
            } catch {
                errorMessage = "Could not save the race: \(error.localizedDescription)"
            }

        case .splitPayload:
            errorMessage = "This looks like a split export QR, not a race config. Ask the host coach for the pre-race \"Share with Coaches\" QR code."
        }
    }
}
```

---

## MODIFY `SplitDeck/Persistence/SplitDeckStore.swift`

Add the following method to `SplitDeckStore`. Place it in a new `// MARK: â Import Support` extension or alongside the existing race-creation methods:

### Before (find the closing brace of the class or the last MARK section)

```swift
    // MARK: â Splits
```

### After

```swift
    // MARK: â Import Support

    /// Create a Race and any missing Athletes from a SharedRaceConfig.
    ///
    /// - Upserts athletes by UUID: if an Athlete with the same UUID already exists, it is
    ///   left unchanged. Otherwise a new Athlete is created from the SharedAthlete data.
    /// - Creates a new Race with `meetId: nil` and `status: .notStarted`.
    /// - Returns the created Race for immediate navigation to LiveTimingView.
    func importRace(from config: SharedRaceConfig) throws -> Race {
        // Upsert athletes
        for sharedAthlete in config.athletes {
            if (try? fetchAthleteEntity(id: sharedAthlete.id)) == nil {
                let athlete = Athlete(
                    id: sharedAthlete.id,
                    name: sharedAthlete.name,
                    teamName: nil,
                    colorHex: sharedAthlete.colorHex,
                    notes: nil,
                    gender: sharedAthlete.gender
                )
                try save(athlete)
            }
        }

        // Create the race (Quick Race on this device, no meet association)
        let race = Race(
            meetId: nil,
            name: config.raceName,
            eventType: config.eventType,
            distanceMeters: config.distanceMeters,
            trackLengthMeters: config.trackLengthMeters,
            splitsPerLap: config.splitsPerLap,
            isUnlimitedSplits: config.isUnlimitedSplits,
            athleteIds: config.athletes.map(\.id),
            status: .notStarted
        )
        try save(race)
        return race
    }

    // MARK: â Splits
```

**Note**: `fetchAthleteEntity(id:)` is the existing private helper used elsewhere in the store that fetches the Core Data entity for a given UUID. If the store uses a different internal helper name, substitute it here. The pattern mirrors the existing `importRace` shape in the plan.

---

## MODIFY `SplitDeck/Views/Home/HomeView.swift`

### Change 1 â Add state variable

Find the `@State` declarations in `HomeView`. Add `showImportRace` alongside the existing state:

#### Before

```swift
    @State private var showNewMeet = false
```

#### After

```swift
    @State private var showNewMeet = false
    @State private var showImportRace = false
```

### Change 2 â Add Import button to the bottom action bar

Find the `quickRaceButton` HStack (the bottom bar that contains the Quick Race and Relay Builder buttons). Add the Import button **before** the existing Relay Builder button:

#### Before

```swift
                    // Relay Builder button (existing)
                    NavigationLink {
                        RelayBuilderView(store: store)
                    } label: {
                        Label("Relay Builder", systemImage: "figure.run.square.stack")
                            .font(.headline)
                            .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.runsmithPink)
```

#### After

```swift
                    // Import Race button
                    Button {
                        showImportRace = true
                    } label: {
                        Label("Import", systemImage: "qrcode.viewfinder")
                            .font(.headline)
                            .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.runsmithPink)

                    // Relay Builder button (existing)
                    NavigationLink {
                        RelayBuilderView(store: store)
                    } label: {
                        Label("Relay Builder", systemImage: "figure.run.square.stack")
                            .font(.headline)
                            .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.runsmithPink)
```

### Change 3 â Add sheet modifier

Find the block of `.sheet` modifiers on `HomeView`'s root view. Add the import sheet alongside the existing ones:

#### Before

```swift
        .sheet(isPresented: $showNewMeet) {
```

#### After

```swift
        .sheet(isPresented: $showImportRace) {
            ImportRaceView(store: store)
        }
        .sheet(isPresented: $showNewMeet) {
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] Home screen bottom action bar shows an "Import" button (qrcode.viewfinder icon) between the Quick Race and Relay Builder buttons
- [ ] Tapping "Import" presents `ImportRaceView` as a sheet
- [ ] `ImportRaceView` opens the camera scanner immediately
- [ ] Scanning a QR code that was generated by `ShareRaceConfigView` (from Step 06) successfully decodes the `SharedRaceConfig`
- [ ] After a successful scan, the success screen shows the race name and correct athlete count
- [ ] After import, all athletes from the config exist in Core Data (check the Athletes roster)
- [ ] Tapping "Start Timing" navigates to `LiveTimingView` with the imported race
- [ ] If the same QR is scanned again (athletes already exist), no duplicate athletes are created
- [ ] Scanning a random / non-Runsmith QR shows the error screen with a descriptive message
- [ ] Scanning a CoachSplitPayload QR (wrong type) shows the specific "split export QR" error message
- [ ] Tapping "Scan Again" on the error screen re-activates the camera scanner
- [ ] Tapping "Cancel" or "Done" dismisses the sheet without creating any data
- [ ] `store.importRace(from:)` compiles and matches the signatures used by `ImportRaceView`
