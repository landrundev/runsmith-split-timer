import SwiftUI

/// Shown when a `.runsmith` file is opened but the meet doesn't exist locally.
struct BulkMergeFileErrorView: View {
    let meetName: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Meet Not Found")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)

                    Text("The file references \"\(meetName)\" but this meet doesn't exist on your device.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Make sure you've imported or created this meet before merging timing data.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(GlassPrimaryButtonStyle())
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Import Error")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
