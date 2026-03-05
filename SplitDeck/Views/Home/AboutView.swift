import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let runsmithURL = URL(string: "https://runsmith.app.link/")!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo + version
                VStack(spacing: 8) {
                    Image("RunsmithLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                    Text("Split Timer")
                        .font(.title2.weight(.bold))
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Divider().padding(.horizontal)

                // About the app
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("About", icon: "stopwatch")
                    Text("Runsmith Split Timer is a precision timing tool built for track & field coaches. Record splits, manage athletes, build relay teams, and analyze results \u{2014} all from your pocket.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Features", icon: "sparkles")

                    featureRow(icon: "timer", title: "Live Split Timing",
                               detail: "Tap-to-mark splits with real-time elapsed clock. Assign marks to athletes on the fly.")
                    featureRow(icon: "person.3.fill", title: "Athlete Management",
                               detail: "Create athlete profiles, track personal bests, and view race history across all meets.")
                    featureRow(icon: "figure.run", title: "Relay Builder",
                               detail: "Build relay teams using PR and average rankings. Save teams and start races directly.")
                    featureRow(icon: "chart.bar.fill", title: "Results & Export",
                               detail: "View results with cumulative and lap time breakdowns. Export to CSV or share as an image card.")
                    featureRow(icon: "tray.full.fill", title: "Meet Organization",
                               detail: "Group races by meet with date and location. Keep your season organized in one place.")
                    featureRow(icon: "arrow.counterclockwise", title: "Crash Recovery",
                               detail: "Mid-race state is saved continuously. Resume right where you left off if the app closes.")
                }
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // Runsmith platform CTA
                VStack(spacing: 12) {
                    sectionHeader("The Runsmith Platform", icon: "globe")

                    Text("Runsmith is the all-in-one coaching platform for track & field. Manage your entire program \u{2014} performance analytics, meet management, team communication, and more \u{2014} from a single dashboard.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        platformFeature("Real-time performance tracking from athletes\u{2019} phones")
                        platformFeature("Analytical dashboard with weather and location context")
                        platformFeature("Compare personal bests, school records, and histories")
                        platformFeature("Dedicated profiles for coaches, athletes, and parents")
                        platformFeature("Notes, goals, and messaging from one place")
                    }
                    .padding(.horizontal)

                    Link(destination: runsmithURL) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Explore Runsmith")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.runsmithPink)
                    .padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // Footer
                VStack(spacing: 6) {
                    Text("Made for coaches, by coaches.")
                        .font(.footnote.weight(.semibold))
                    Text("runsmith.com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Theme.runsmithPink)
            Text(title)
                .font(.headline)
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.runsmithPink)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func platformFeature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
