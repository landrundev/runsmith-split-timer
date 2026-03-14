import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSwitchToFan = false
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
                    Text("Runsmith Split Timer is a precision timing tool built for track & field coaches. Time individual and relay events from 100m to 10,000m, manage rosters, coordinate multi-coach timing, and analyze your season \u{2014} all from your pocket.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Features", icon: "sparkles")

                    featureRow(icon: "timer", title: "Live Split Timing",
                               detail: "Tap-to-mark splits with real-time elapsed clock. Assign marks to athletes on the fly or tap athlete cards directly.")
                    featureRow(icon: "figure.run", title: "Relay Builder",
                               detail: "Build 4\u{00D7}100m, 4\u{00D7}200m, 4\u{00D7}400m, and 4\u{00D7}800m relay teams using PR rankings. Save teams, reorder legs, and record optional intermediate splits.")
                    featureRow(icon: "person.2.wave.2", title: "Multi-Coach Timing",
                               detail: "Share race configs via QR code or file. Assistant coaches time independently, then merge splits back to the host.")
                    featureRow(icon: "chart.xyaxis.line", title: "Analytics Dashboard",
                               detail: "Season overview, personal records board, event leaderboards, athlete insights with consistency scores, and PR trend sparklines.")
                    featureRow(icon: "person.3.fill", title: "Athlete Profiles",
                               detail: "Per-athlete race history, personal bests by event, relay team context, and split-level PRs across all meets.")
                    featureRow(icon: "chart.bar.fill", title: "Results & Export",
                               detail: "Cumulative and lap time views. Share results as image cards or export to CSV. Relay results show per-leg and intermediate breakdowns.")
                    featureRow(icon: "tray.full.fill", title: "Meet Organization",
                               detail: "Group races by meet with date and location. Gender-filtered rosters, heat labels, and full archive system.")
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

                // Switch mode
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showSwitchToFan = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Switch to Fan Mode")
                                    .font(.subheadline.weight(.semibold))
                                Text("Time your own athlete and track their PRs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .padding(.horizontal)

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
        .confirmationDialog("Switch to Fan Mode?",
                            isPresented: $showSwitchToFan,
                            titleVisibility: .visible) {
            Button("Switch to Fan Mode") {
                AppSettings.appMode = .spectator
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your meets, rosters, and race history are kept. Switch back anytime.")
        }
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
