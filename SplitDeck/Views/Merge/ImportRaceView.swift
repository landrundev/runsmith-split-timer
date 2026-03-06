import SwiftUI
import UniformTypeIdentifiers

/// Presented to assistant coaches from the Home screen.
/// Shows a method picker (Scan QR / Import File / Paste Text), then
/// creates athletes + races in Core Data and offers navigation options.
struct ImportRaceView: View {
    let store: SplitDeckStore
    let cache: RaceStateCache

    @Environment(\.dismiss) private var dismiss

    // MARK: — State

    @State private var scannedString: String? = nil
    @State private var importedRace: Race? = nil
    @State private var importedConfig: SharedRaceConfig? = nil
    @State private var importedMeet: Meet? = nil
    @State private var importedMeetConfig: SharedMeetConfig? = nil
    @State private var errorMessage: String? = nil
    @State private var isScanning: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var navigateToTiming: Bool = false
    @State private var showMethodPicker: Bool = true

    // MARK: — Body

    var body: some View {
        NavigationStack {
            Group {
                if let meet = importedMeet, let meetConfig = importedMeetConfig {
                    meetSuccessView(meet: meet, config: meetConfig)
                } else if let race = importedRace, let config = importedConfig {
                    raceSuccessView(race: race, config: config)
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if isScanning {
                    scannerView
                } else if showMethodPicker {
                    methodPickerView
                } else {
                    ProgressView("Importing…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToTiming) {
                if let race = importedRace {
                    let athletes = (try? store.fetchAthletes()) ?? []
                    let liveVM = LiveTimingViewModel(
                        race: race, athletes: athletes, store: store, cache: cache
                    )
                    LiveTimingView(vm: liveVM, cache: cache)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.json, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .onChange(of: scannedString) { newValue in
            guard let scanned = newValue else { return }
            isScanning = false
            showMethodPicker = false
            processScannedString(scanned)
        }
    }

    // MARK: — Method Picker

    private var methodPickerView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(Theme.runsmithPink)

            Text("How did you receive the race config?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    showMethodPicker = false
                    isScanning = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPrimaryButtonStyle())

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import File", systemImage: "doc.badge.plus")
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
            Text("Point camera at the host coach's QR code")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 48)
        }
    }

    // MARK: — Success (Race)

    private func raceSuccessView(race: Race, config: SharedRaceConfig) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.runsmithPink)

            VStack(spacing: 8) {
                Text("Race Imported!")
                    .font(.title2.bold())

                if let meetName = config.meetName {
                    Text(meetName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(race.name)
                    .font(config.meetName != nil ? .subheadline : .headline)
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
                }
                .buttonStyle(GlassPrimaryButtonStyle())

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: — Success (Meet)

    private func meetSuccessView(meet: Meet, config: SharedMeetConfig) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.runsmithPink)

            VStack(spacing: 8) {
                Text("Meet Imported!")
                    .font(.title2.bold())

                Text(meet.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                let raceCount = config.races.count
                let uniqueAthletes = Set(config.races.flatMap { $0.athletes.map(\.id) }).count
                Text("\(raceCount) race\(raceCount == 1 ? "" : "s"), \(uniqueAthletes) athlete\(uniqueAthletes == 1 ? "" : "s") ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                errorMessage = nil
                scannedString = nil
                showMethodPicker = true
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: — Logic

    private func processScannedString(_ string: String) {
        guard let content = PayloadEncoder.decodeQR(string) else {
            errorMessage = "This doesn't appear to be a valid Runsmith config. Make sure you're using data from the host coach's share screen."
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

        case .meetConfig(let config):
            do {
                let meet = try store.importMeet(from: config)
                importedMeetConfig = config
                importedMeet = meet
            } catch {
                errorMessage = "Could not save the meet: \(error.localizedDescription)"
            }

        case .splitPayload:
            errorMessage = "This looks like a split export, not a race config. Ask the host coach for the pre-race share data."
        }
    }

    private func processJSONData(_ data: Data) {
        // Try meet config first (more specific), then race config
        if let meetConfig = PayloadEncoder.decodeMeetConfig(from: data) {
            do {
                let meet = try store.importMeet(from: meetConfig)
                importedMeetConfig = meetConfig
                importedMeet = meet
            } catch {
                errorMessage = "Could not save the meet: \(error.localizedDescription)"
            }
        } else if let config = PayloadEncoder.decodeRaceConfig(from: data) {
            do {
                let race = try store.importRace(from: config)
                importedConfig = config
                importedRace = race
            } catch {
                errorMessage = "Could not save the race: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "The file doesn't appear to be a valid Runsmith race or meet config."
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        showMethodPicker = false
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Could not read the file."
                return
            }
            processJSONData(data)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func pasteFromClipboard() {
        showMethodPicker = false
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            errorMessage = "Nothing on the clipboard. Ask the host coach to tap \"Copy QR String\" and send it to you."
            return
        }
        processScannedString(pasted)
    }
}
