import SwiftUI

struct LiveTimingView: View {
    @ObservedObject var vm: LiveTimingViewModel
    let cache: RaceStateCache
    var onRaceComplete: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            clockHeader
            athleteList
            bottomBar
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.race.status == .inProgress)
        .toolbar {
            if vm.race.status == .inProgress {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Finish") {
                        vm.showFinishConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .alert("Finish Race?", isPresented: $vm.showFinishConfirmation) {
            Button("Finish", role: .destructive) { vm.finishRace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the race and save all results.")
        }
        .alert("Resume Race?", isPresented: $vm.showResumePrompt) {
            Button("Resume") { vm.resumeRace() }
            Button("Start Fresh", role: .destructive) { vm.discardAndStartFresh() }
        } message: {
            Text("A previous session was found. Do you want to resume where you left off?")
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                cache.flushImmediately(vm.currentBlob)
            }
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .onChange(of: vm.shouldDismiss) { should in
            if should {
                if let onRaceComplete {
                    onRaceComplete()   // Quick Race: dismiss the whole sheet
                } else {
                    dismiss()          // Meet race: pop back to MeetDetail
                }
            }
        }
        .navigationDestination(isPresented: $vm.navigateToResults) {
            if let resultsVM = vm.resultsViewModel {
                ResultsView(vm: resultsVM, onDone: { vm.shouldDismiss = true })
            }
        }
    }

    // MARK: – Clock Header

    private var clockHeader: some View {
        VStack(spacing: 6) {
            Text(vm.engine.elapsedMs.formattedSplitTime)
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Text(vm.lapSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !vm.isRelay { unassignedBadge }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.bar)
    }

    // MARK: – Unassigned Badge

    @State private var badgePulse = false
    @State private var previousUnassignedCount = 0

    private var unassignedCount: Int { vm.engine.unassignedMarks.count }

    private var unassignedBadge: some View {
        let hasMarks = unassignedCount > 0
        return Text(hasMarks ? "Unassigned: \(unassignedCount)" : "Unassigned: 0")
            .font(.caption.weight(hasMarks ? .bold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(hasMarks ? Theme.badgeYellow : Color(.systemFill))
            .foregroundStyle(hasMarks ? Color.black : Color.secondary)
            .clipShape(Capsule())
            .scaleEffect(badgePulse ? 1.15 : 1.0)
            .onChange(of: unassignedCount) { newCount in
                if previousUnassignedCount == 0 && newCount > 0 {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                        badgePulse = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { badgePulse = false }
                    }
                }
                previousUnassignedCount = newCount
            }
    }

    // MARK: – Athlete List

    private var athleteList: some View {
        Group {
            if vm.isRelay {
                relayAthleteList
            } else {
                regularAthleteList
            }
        }
    }

    private var useCompactGrid: Bool { vm.athletes.count > 8 }

    private var regularAthleteList: some View {
        ScrollView {
            if useCompactGrid {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(vm.athletes) { athlete in
                        CompactAthleteCardView(
                            athlete: athlete,
                            lastLapDelta: vm.lastLapDelta(for: athlete),
                            lapProgress: vm.lapProgress(for: athlete),
                            isComplete: RaceDomain.isComplete(
                                athlete: athlete, splits: vm.splits, race: vm.race)
                        ) {
                            vm.assign(to: athlete)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.athletes) { athlete in
                        AthleteCardView(
                            athlete: athlete,
                            splitTimes: vm.splitTimesForDisplay(for: athlete),
                            lapProgress: vm.lapProgress(for: athlete),
                            isComplete: RaceDomain.isComplete(
                                athlete: athlete, splits: vm.splits, race: vm.race)
                        ) {
                            vm.assign(to: athlete)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var relayAthleteList: some View {
        List {
            ForEach(Array(vm.athletes.enumerated()), id: \.element.id) { i, athlete in
                relayLegRow(legIndex: i, athlete: athlete)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .moveDisabled(i < vm.currentRelayLeg)
            }
            .onMove { vm.moveRelayLeg(from: $0, to: $1) }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    private func relayLegRow(legIndex: Int, athlete: Athlete) -> some View {
        let legNumber = legIndex + 1
        let isCurrent = legIndex == vm.currentRelayLeg && !vm.isRelayComplete
        let isDone    = legIndex < vm.currentRelayLeg
        let isWaiting = !isCurrent && !isDone
        let legSplit  = vm.splits.first { $0.athleteId == athlete.id }

        return HStack(spacing: 12) {
            // Leg badge
            Text("LEG\n\(legNumber)")
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(8)
                .background(isCurrent ? Theme.runsmithPink : (isDone ? Color(.systemGreen) : Color(.systemFill)))
                .foregroundStyle(isCurrent || isDone ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 44)

            // Color bar + name
            Rectangle()
                .fill(Color(hex: athlete.colorHex))
                .frame(width: 4)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(athlete.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrent ? .primary : (isDone ? .secondary : .tertiary))
                if isCurrent {
                    Text("Tap to record split")
                        .font(.caption)
                        .foregroundStyle(Theme.runsmithPink)
                } else if isDone, let split = legSplit {
                    Text(split.elapsedMs.formattedSplitTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Waiting")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isCurrent {
                Image(systemName: "figure.run")
                    .foregroundStyle(Theme.runsmithPink)
            } else if isWaiting {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Theme.runsmithPink.opacity(0.06) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCurrent ? Theme.runsmithPink.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if isCurrent {
                vm.recordRelayLeg()
            }
        }
    }

    // MARK: – Bottom Bar

    private var bottomBar: some View {
        Group {
            if vm.isRelay {
                relayBottomBar
            } else {
                regularBottomBar
            }
        }
    }

    private var regularBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                vm.undo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("UNDO")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: Theme.markButtonHeight)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .disabled(vm.engine.undoStack.isEmpty)

            if vm.allAthletesComplete {
                Button {
                    vm.showFinishConfirmation = true
                } label: {
                    Text("END RACE")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.markButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button {
                    vm.mark()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text("MARK SPLIT")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: Theme.markButtonHeight)

                        if unassignedCount > 0 {
                            Text("\(unassignedCount)")
                                .font(.caption2.weight(.bold))
                                .padding(5)
                                .background(Theme.badgeYellow)
                                .foregroundStyle(.black)
                                .clipShape(Circle())
                                .offset(x: -4, y: 4)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)
                .disabled(vm.race.status == .completed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var relayBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                vm.undo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("UNDO")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: Theme.markButtonHeight)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .disabled(vm.engine.undoStack.isEmpty)

            if vm.isRelayComplete {
                Button {
                    vm.showFinishConfirmation = true
                } label: {
                    Text("FINISH RELAY")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.markButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button {
                    vm.recordRelayLeg()
                } label: {
                    Text("RECORD LEG \(vm.currentRelayLeg + 1)")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.markButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.runsmithPink)
                .disabled(vm.race.status == .completed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
