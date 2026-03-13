import SwiftUI

struct LiveTimingView: View {
    @ObservedObject var vm: LiveTimingViewModel
    let cache: RaceStateCache
    var onRaceComplete: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWideLayout: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            clockHeader
            if !vm.isRelay {
                TipCardView(
                    tipId: "markSplit",
                    icon: "hand.tap",
                    message: "Tap MARK SPLIT when a runner crosses the line. Then tap the athlete\u{2019}s card to assign it. Unassigned marks are held until you assign them."
                )
            } else if vm.race.splitsPerLap > 1 {
                TipCardView(
                    tipId: "relayIntermediateSplits",
                    icon: "stopwatch",
                    message: "Intermediate splits are ON. You\u{2019}ll record \(vm.race.splitsPerLap) taps per athlete \u{2014} one every \(vm.race.intermediateDistanceMeters.map { "\($0)m" } ?? "split"). Each tap records a cumulative time; leg splits are calculated automatically."
                )
            } else {
                TipCardView(
                    tipId: "relayTiming",
                    icon: "figure.run",
                    message: "Tap the current runner\u{2019}s row or the bottom button to record each leg. Drag rows to reorder legs mid-race."
                )
            }
            athleteList
            bottomBar
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.race.status == .inProgress || vm.race.status == .completed)
        .interactiveDismissDisabled(vm.race.status == .inProgress)
        .gesture(vm.race.status == .inProgress ? DragGesture() : nil)
        .toolbar {
            if vm.race.status == .inProgress {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Finish") {
                        if vm.hasIncompleteAthletes {
                            vm.showDNFConfirmation = true
                        } else {
                            vm.showFinishConfirmation = true
                        }
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
        .confirmationDialog(
            "Not all athletes have finished",
            isPresented: $vm.showDNFConfirmation,
            titleVisibility: .visible
        ) {
            Button("End & Record DNFs") { vm.finishRace() }
            Button("End Without Saving", role: .destructive) { vm.discardRace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Some athletes have incomplete splits. You can save with DNFs or discard this race.")
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
                .foregroundStyle(Theme.textPrimary)

            Text(vm.lapSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            if !vm.isRelay { unassignedBadge }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.barBackground)
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
            .foregroundStyle(hasMarks ? Color.black : Theme.textSecondary)
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

    private var useCompactGrid: Bool { vm.athletes.count > (isWideLayout ? 16 : 8) }

    private var compactGridColumns: [GridItem] {
        let count = isWideLayout ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var regularAthleteList: some View {
        ScrollView {
            if useCompactGrid {
                LazyVGrid(columns: compactGridColumns, spacing: 8) {
                    ForEach(vm.athletes) { athlete in
                        CompactAthleteCardView(
                            athlete: athlete,
                            lastLapDelta: vm.lastLapDelta(for: athlete),
                            lapProgress: vm.lapProgress(for: athlete),
                            isComplete: RaceDomain.isComplete(
                                athlete: athlete, splits: vm.splits, race: vm.race),
                            finishTime: vm.finishTimeForDisplay(for: athlete)
                        ) {
                            vm.assign(to: athlete)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else if isWideLayout {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(vm.athletes) { athlete in
                        AthleteCardView(
                            athlete: athlete,
                            splitTimes: vm.splitTimesForDisplay(for: athlete),
                            lapProgress: vm.lapProgress(for: athlete),
                            isComplete: RaceDomain.isComplete(
                                athlete: athlete, splits: vm.splits, race: vm.race),
                            finishTime: vm.finishTimeForDisplay(for: athlete)
                        ) {
                            vm.assign(to: athlete)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.athletes) { athlete in
                        AthleteCardView(
                            athlete: athlete,
                            splitTimes: vm.splitTimesForDisplay(for: athlete),
                            lapProgress: vm.lapProgress(for: athlete),
                            isComplete: RaceDomain.isComplete(
                                athlete: athlete, splits: vm.splits, race: vm.race),
                            finishTime: vm.finishTimeForDisplay(for: athlete)
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
        .frame(maxWidth: isWideLayout ? 700 : .infinity)
    }

    private func relayLegRow(legIndex: Int, athlete: Athlete) -> some View {
        let legNumber = legIndex + 1
        let isCurrent = legIndex == vm.currentRelayLeg && !vm.isRelayComplete
        let isDone    = legIndex < vm.currentRelayLeg
        let isWaiting = !isCurrent && !isDone
        let hasIntermediates = vm.race.splitsPerLap > 1

        return HStack(spacing: 12) {
            // Leg badge
            Text("LEG\n\(legNumber)")
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(8)
                .background(isCurrent ? Theme.runsmithPink : (isDone ? Color(.systemGreen) : Color(.systemFill)))
                .foregroundStyle(isCurrent || isDone ? .white : Theme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 44)

            // Color bar + name
            Rectangle()
                .fill(Color(hex: athlete.colorHex))
                .frame(width: 4)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(athlete.firstName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrent ? Theme.textPrimary : (isDone ? Theme.textSecondary : Theme.textTertiary))

                if isCurrent {
                    if hasIntermediates {
                        // Show already-recorded intermediate splits (lap time as primary)
                        let partialDetails = vm.relayLegSplitDetails(legIndex: legIndex)
                        if !partialDetails.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(Array(partialDetails.enumerated()), id: \.offset) { _, detail in
                                    VStack(spacing: 0) {
                                        Text(detail.label)
                                            .font(.system(size: 9))
                                            .foregroundStyle(Theme.textTertiary)
                                        Text(detail.lapMs.formattedSplitTime)
                                            .font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(Theme.runsmithPink)
                                    }
                                }
                            }
                        }
                        if let distLabel = vm.currentSplitDistanceLabel {
                            Text("Tap to record \(distLabel) split")
                                .font(.caption)
                                .foregroundStyle(Theme.runsmithPink)
                        }
                    } else {
                        Text("Tap to record split")
                            .font(.caption)
                            .foregroundStyle(Theme.runsmithPink)
                    }
                } else if isDone {
                    if hasIntermediates {
                        // Show intermediate splits (lap times) under name
                        let details = vm.relayLegSplitDetails(legIndex: legIndex)
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                                VStack(spacing: 0) {
                                    Text(detail.label)
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.textTertiary)
                                    Text(detail.lapMs.formattedSplitTime)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("Waiting")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            if isDone {
                let cumulMs = vm.splits.filter({ $0.athleteId == athlete.id })
                    .max(by: { $0.elapsedMs < $1.elapsedMs })?.elapsedMs
                VStack(alignment: .trailing, spacing: 2) {
                    if let delta = vm.relayLegDelta(legIndex: legIndex) {
                        Text(delta.formattedSplitTime)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    if let cumul = cumulMs {
                        Text(cumul.formattedSplitTime)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isCurrent {
                // Live elapsed time for current leg
                let prevLegEndMs: Int = {
                    if legIndex > 0 {
                        let prevId = vm.race.athleteIds[legIndex - 1]
                        return vm.splits.filter { $0.athleteId == prevId }
                            .max(by: { $0.elapsedMs < $1.elapsedMs })?.elapsedMs ?? 0
                    }
                    return 0
                }()
                let legElapsed = max(0, vm.engine.elapsedMs - prevLegEndMs)
                VStack(spacing: 2) {
                    Text(legElapsed.formattedSplitTime)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.runsmithPink)
                    if vm.isCurrentLegPartial {
                        Text("\(vm.currentLegSplitNumber - 1)/\(vm.race.splitsPerLap)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            } else if isWaiting {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.textTertiary)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(isCurrent ? Theme.accentBackground : Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(isCurrent ? Theme.runsmithPink.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
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
            .tint(Theme.textSecondary)
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
        .background(Theme.barBackground)
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
            .tint(Theme.textSecondary)
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
                    Group {
                        if vm.race.splitsPerLap > 1, let distLabel = vm.currentSplitDistanceLabel {
                            Text("RECORD \(distLabel)")
                        } else {
                            Text("RECORD LEG \(vm.currentRelayLeg + 1)")
                        }
                    }
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
        .background(Theme.barBackground)
    }
}
