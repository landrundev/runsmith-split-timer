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
                    if let meetName = config.meetName {
                        HStack {
                            Label("Meet", systemImage: "calendar")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(meetName)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
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

        // Scale up for crisp rendering at 220x220 pt display size
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
