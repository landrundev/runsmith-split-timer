import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Shown to assistant coaches after their race ends.
/// Displays a QR code of the CoachSplitPayload that the host coach scans
/// to merge splits together.
struct ExportSplitsView: View {
    let payload: CoachSplitPayload

    @Environment(\.dismiss) private var dismiss

    // MARK: – State

    @State private var coachName: String = CoachIdentity.name ?? ""
    @State private var qrImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var copyConfirmed = false
    @State private var showNamePrompt = false
    @State private var promptName: String = ""

    // MARK: – Computed

    /// Re-encode payload with the current coach name whenever it changes.
    private var currentPayload: CoachSplitPayload {
        CoachSplitPayload(
            version: payload.version,
            configId: payload.configId,
            coachName: coachName.isEmpty ? "Coach" : coachName,
            exportedAt: payload.exportedAt,
            athleteSplits: payload.athleteSplits,
            raceName: payload.raceName,
            eventType: payload.eventType,
            meetName: payload.meetName
        )
    }

    private var qrString: String {
        PayloadEncoder.encodeForQR(currentPayload) ?? ""
    }

    private var athleteCount: Int { payload.athleteSplits.count }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            List {
                raceContextSection
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
            .onChange(of: coachName) { _ in
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

    // MARK: – Sections

    private var raceContextSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if let name = payload.raceName {
                    HStack(spacing: 6) {
                        Image(systemName: "stopwatch")
                            .foregroundStyle(Theme.runsmithPink)
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                HStack(spacing: 12) {
                    if let event = payload.eventType {
                        Label(event, systemImage: "figure.run")
                    }
                    if let meet = payload.meetName {
                        Label(meet, systemImage: "flag")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Race")
        }
    }

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
            Text("Shown on the host's merge screen. Tap \u{2713} to save for future exports.")
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
                        "\(coachName.isEmpty ? "Coach" : coachName) \u{2014} Split Export",
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

    // MARK: – Helpers

    private var sanitizedCoachName: String {
        let cleaned = coachName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return cleaned.isEmpty ? "export" : cleaned
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
