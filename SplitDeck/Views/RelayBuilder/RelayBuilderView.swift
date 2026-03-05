import SwiftUI

struct RelayBuilderView: View {
    @ObservedObject var vm: RelayBuilderViewModel
    @EnvironmentObject var cache: RaceStateCache

    @State private var showSaveTeamAlert = false
    @State private var saveTeamName = ""
    @State private var navigateToLiveTiming = false
    @State private var liveTimingVM: LiveTimingViewModel?

    var body: some View {
        VStack(spacing: 0) {
            configSection
            Divider()

            List {
                chosenTeamSection
                if !vm.filteredSavedTeams.isEmpty {
                    savedTeamsSection
                }
                candidateListSection
            }
            .listStyle(.insetGrouped)

            if vm.isTeamComplete {
                actionBar
            }
        }
        .navigationTitle("Relay Builder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load() }
        .alert("Save Relay Team", isPresented: $showSaveTeamAlert) {
            TextField("Team name", text: $saveTeamName)
            Button("Save") {
                let name = saveTeamName.trimmingCharacters(in: .whitespaces)
                vm.saveTeam(name: name.isEmpty ? defaultTeamName : name)
                saveTeamName = ""
            }
            Button("Cancel", role: .cancel) { saveTeamName = "" }
        }
        .navigationDestination(isPresented: $navigateToLiveTiming) {
            if let liveVM = liveTimingVM {
                LiveTimingView(vm: liveVM, cache: cache)
            }
        }
    }

    private var defaultTeamName: String {
        "\(vm.selectedGender.displayName) \(vm.selectedRelayType.displayName)"
    }

    // MARK: – Config (relay type + gender + ranking)

    private var configSection: some View {
        VStack(spacing: 10) {
            Picker("Relay", selection: $vm.selectedRelayType) {
                ForEach(RelayRecommender.supportedRelayTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Picker("Division", selection: $vm.selectedGender) {
                ForEach(Gender.allCases, id: \.self) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)

            Picker("Ranking", selection: $vm.rankingMode) {
                ForEach(RankingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: – Chosen team

    private var chosenTeamSection: some View {
        Section {
            ForEach(Array(vm.chosenCandidates.enumerated()), id: \.element.id) { i, candidate in
                HStack(spacing: 12) {
                    legBadge(i + 1, filled: true)
                    Circle()
                        .fill(Color(hex: candidate.athlete.colorHex))
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(candidate.athlete.name).font(.body)
                        if vm.rankingMode != .roster {
                            Text(candidate.bestTimeMs.formattedSplitTime)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if vm.rankingMode != .roster {
                        sourceBadge(candidate.source)
                    }
                    Button { vm.toggleAthlete(candidate.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.quaternaryLabel))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onMove { vm.moveLeg(from: $0, to: $1) }

            // Empty leg placeholders
            ForEach(vm.chosenAthleteIds.count..<4, id: \.self) { i in
                HStack(spacing: 12) {
                    legBadge(i + 1, filled: false)
                    Text(vm.rankingMode == .roster ? "Select from roster below" : "Select from rankings below")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            // Projected total
            if let total = vm.projectedTotalMs {
                HStack {
                    Text("Projected Total")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(total.formattedSplitTime)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                }
            }

            // Suggested order
            if vm.suggestedOrder != nil {
                Button {
                    vm.applySuggestedOrder()
                } label: {
                    Label("Use Suggested Leg Order", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }
            }
        } header: {
            HStack {
                Text("Relay Team")
                Spacer()
                Text("\(vm.chosenAthleteIds.count)/4")
                    .font(.caption)
                    .foregroundStyle(vm.isTeamComplete ? Theme.runsmithPink : .secondary)
            }
        }
    }

    // MARK: – Saved Teams

    private var savedTeamsSection: some View {
        Section {
            ForEach(vm.filteredSavedTeams) { team in
                Button { vm.loadTeam(team) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(team.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(team.eventType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        teamMembersRow(team.athleteIds)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vm.deleteTeam(team)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Saved Teams")
        }
    }

    private func teamMembersRow(_ athleteIds: [UUID]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(athleteIds.enumerated()), id: \.offset) { i, id in
                if let athlete = vm.athlete(for: id) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: athlete.colorHex))
                            .frame(width: 8, height: 8)
                        Text(athlete.name.components(separatedBy: " ").first ?? athlete.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if i < athleteIds.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: – Ranked candidates

    private var candidateListSection: some View {
        Section {
            if vm.candidates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Athletes Found")
                        .font(.headline)
                    if vm.rankingMode == .roster {
                        Text("No \(vm.selectedGender.displayName.lowercased()) athletes in your roster yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No \(vm.selectedGender.displayName.lowercased()) athletes have \(vm.legDistanceDisplay) data yet. Try \"Roster\" to see all athletes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(vm.candidates.enumerated()), id: \.element.id) { rank, candidate in
                    let isChosen = vm.chosenAthleteIds.contains(candidate.id)
                    HStack(spacing: 12) {
                        if vm.rankingMode != .roster {
                            Text("\(rank + 1)")
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                        Circle()
                            .fill(Color(hex: candidate.athlete.colorHex))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(candidate.athlete.name).font(.body)
                            if let team = candidate.athlete.teamName {
                                Text(team).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if vm.rankingMode != .roster {
                            sourceBadge(candidate.source)
                            Text(candidate.bestTimeMs.formattedSplitTime)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        if isChosen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.runsmithPink)
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(vm.isTeamComplete ? Color(.quaternaryLabel) : Theme.runsmithPink)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { vm.toggleAthlete(candidate.id) }
                    .opacity(vm.isTeamComplete && !isChosen ? 0.4 : 1.0)
                }
            }
        } header: {
            HStack {
                if vm.rankingMode == .roster {
                    Text("\(vm.selectedGender.displayName) Roster")
                } else {
                    Text("\(vm.selectedRelayType.displayName) Rankings (\(vm.rankingMode.rawValue))")
                }
                Spacer()
                Text("\(vm.candidates.count) athletes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: – Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                saveTeamName = defaultTeamName
                showSaveTeamAlert = true
            } label: {
                Label("Save Team", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(GlassSecondaryButtonStyle())

            Button {
                guard let race = vm.startRace(meetId: nil) else { return }
                let athletes = (try? vm.store.fetchAthletes()) ?? []
                liveTimingVM = LiveTimingViewModel(
                    race: race, athletes: athletes, store: vm.store, cache: cache
                )
                navigateToLiveTiming = true
            } label: {
                Label("Start Race", systemImage: "stopwatch")
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
        .glassActionBar()
    }

    // MARK: – Helpers

    private func legBadge(_ number: Int, filled: Bool) -> some View {
        Text("\(number)")
            .font(.footnote.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(filled ? Theme.runsmithPink : Color(.quaternaryLabel))
            .clipShape(Circle())
    }

    private func sourceBadge(_ source: AthleteRelayCandidate.TimeSource) -> some View {
        let (label, tint): (String, Color) = {
            switch source {
            case .individualPB: return ("PR", .green)
            case .splitFromRace: return ("Split", .secondary)
            case .average(let count): return ("Avg (\(count))", .blue)
            case .roster: return ("", .clear)
            }
        }()
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }
}
