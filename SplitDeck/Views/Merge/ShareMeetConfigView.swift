import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Shown when the host taps "Share with Coaches" from MeetDetailView.
/// Displays a QR code and share/copy options for the SharedMeetConfig.
struct ShareMeetConfigView: View {
    let config: SharedMeetConfig

    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage? = nil
    @State private var copyConfirmed = false

    private var qrString: String {
        PayloadEncoder.encodeForQR(config) ?? ""
    }

    private var raceSummary: String {
        let count = config.races.count
        return "\(count) race\(count == 1 ? "" : "s")"
    }

    private var athleteSummary: String {
        // Deduplicate athletes across all races
        let uniqueIds = Set(config.races.flatMap { $0.athletes.map(\.id) })
        let count = uniqueIds.count
        return "\(count) athlete\(count == 1 ? "" : "s")"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                // MARK: — Meet + Coach Info
                Section {
                    HStack {
                        Label("Sharing as", systemImage: "person.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(config.hostCoachName)
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        Label("Meet", systemImage: "calendar")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(config.meetName)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Date", systemImage: "clock")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Self.dateFormatter.string(from: config.meetDate))
                            .foregroundStyle(.primary)
                    }
                    if let location = config.meetLocation {
                        HStack {
                            Label("Location", systemImage: "mappin")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(location)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    HStack {
                        Label("Races", systemImage: "flag.checkered")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(raceSummary)
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        Label("Athletes", systemImage: "person.3")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(athleteSummary)
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Meet Info")
                }

                // MARK: — Race List
                if !config.races.isEmpty {
                    Section {
                        ForEach(config.races, id: \.configId) { race in
                            HStack {
                                Text(race.raceName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(race.athletes.count) athlete\(race.athletes.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Included Races")
                    }
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
                    Text("Scan to Import Meet")
                } footer: {
                    Text("Assistant coaches scan this code to receive the meet setup and all races on their device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: — Action Buttons
                Section {
                    if let jsonData = PayloadEncoder.encodeJSON(config),
                       let url = writeToTemporaryFile(data: jsonData, filename: "meet-config.json") {
                        ShareLink(item: url, preview: SharePreview(config.meetName, icon: Image(systemName: "calendar"))) {
                            Label("Share File", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }

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
            .navigationTitle("Share Meet")
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
