# Runsmith Split Timer — Project Documentation

**Version 1.3 (Build 16) | March 2026**

---

## Overview

Runsmith Split Timer is an iOS split-timing app built for track & field coaches. Record splits, manage athletes, build relay teams, and analyze results — all offline from your pocket.

- **Bundle ID**: `com.runsmith.splitdeck`
- **Platform**: iOS 16+, SwiftUI, Core Data
- **Networking**: Fully offline — all data stored locally on device
- **Project Generation**: XcodeGen (`project.yml` → `xcodegen generate`)

---

## Architecture

```
Models → Persistence → Domain → ViewModels → Views
```

Layered architecture with no skip-layer dependencies:

| Layer | Description | Examples |
|-------|-------------|----------|
| **Models** | Plain Codable structs, no NSManagedObject exposed | Race, Athlete, Split, Meet, SavedRelayTeam |
| **Persistence** | Core Data CRUD + crash recovery | SplitDeckStore, RaceStateCache |
| **Domain** | Pure logic, no SwiftUI/CoreData | RaceDomain, TimingEngine, CSVExporter, RelayRecommender |
| **ViewModels** | @MainActor ObservableObject, DI at app root | LiveTimingViewModel, RaceSetupViewModel |
| **Views** | SwiftUI views | LiveTimingView, HomeView, ResultsView |

### Key Files

| File | Purpose |
|------|---------|
| `SplitDeck/App/SplitDeckApp.swift` | App entry, dependency injection wiring |
| `SplitDeck/Domain/TimingEngine.swift` | Highest-risk: owns CADisplayLink + undo stack |
| `SplitDeck/Domain/RaceDomain.swift` | Pure business logic + ordinal-based display |
| `SplitDeck/Domain/RelayRecommender.swift` | Relay team ranking + leg order |
| `SplitDeck/Persistence/SplitDeckStore.swift` | Core Data CRUD operations |
| `SplitDeck/Persistence/RaceStateCache.swift` | Mid-race crash recovery (JSON blob) |
| `SplitDeck/Views/LiveTiming/LiveTimingView.swift` | Main timing screen |
| `SplitDeck/Views/Home/HomeView.swift` | Home screen with meets + quick races |
| `SplitDeck/Views/Home/AboutView.swift` | About page with platform link |
| `SplitDeck/Views/RelayBuilder/RelayBuilderView.swift` | Standalone relay team builder |
| `SplitDeck/Views/AthleteProfile/AthleteRosterView.swift` | Full CRUD athlete roster |
| `SplitDeck/Views/AthleteProfile/AthleteProfileView.swift` | Athlete profile + race history |

---

## Completed Features (v1.3)

### Core Timing
- Full timing loop: Race Setup → Live Timing → Results → Done
- Quick Race: dismiss to Home on done; Meet Race: pop to MeetDetailView
- Elapsed time always recomputed from `startedAt` (never accumulated)
- CADisplayLink on `.common` run loop mode (prevents scroll freeze)
- Crash recovery: mid-race state saved continuously (unassigned marks + undo stack)
- Each Split saved to Core Data immediately on assignment (not batched)
- Adjustable splits per lap (1–4) via Stepper in race setup

### Event Types
- Individual: 400m, 800m, 1500m, Mile, 1600m, 3200m, 5K, 10K, Custom
- Relay: 4x100m, 4x200m, 4x400m, 4x800m
- Unlimited splits mode: toggle in setup, no auto-complete, manual finish

### Athletes
- Full CRUD: add/edit/delete from Roster, Profile, and Race Setup
- Gender: mandatory M/F toggle (blue/pink), Add/Save disabled until set
- Gender filter: All/M/F buttons on Roster and Race Setup
- Color palette picker for athlete identity
- Athlete profiles: personal bests, race history with expandable split details
- Swipe-to-delete on race history entries (with confirmation)
- 50-athlete per-race cap with dimmed UI when full

### Live Timing
- Adaptive layout: full cards (≤8 athletes) or compact 2-column grid (9+)
- Full cards: inline scrollable split chips (lap delta + label)
- Compact grid: last lap delta (bold) + cumulative time
- Gender color bars on left edge of all cards
- Athlete identity dots (color circles) next to names

### Relay System
- Relay race setup with drag-to-reorder leg assignments
- Relay builder: standalone tool with PR/Average ranking toggle
- Saved relay teams: save, load, start race directly
- Two-tier time lookup: individual PBs preferred, split-from-longer-race fallback
- Leg order strategy: 2nd fastest → Leg 1, 3rd → Leg 2, slowest → Leg 3, fastest → anchor
- Gender filter on relay builder candidates

### Results & Export
- Vertical card layout with Cumulative/Lap Times toggle
- CSV export with ordinal-based column labels
- Share card image generation
- Ordinal-based display: sort splits by elapsed time, index by position

### Organization
- Meet management: create, edit, delete (cascades to races + splits)
- Quick Race history with gender color bars (blue/pink/gradient for mixed)
- Swipe-to-delete on meets and races
- About page: clickable logo → app info + Runsmith platform link

### Branding
- Runsmith logo in nav bar (clickable → About page)
- Pink app icon (1024x1024)
- Consistent pink accent color throughout (`Theme.runsmithPink`)

---

## Critical Constraints

1. `laps` and `expectedSplitsPerAthlete` are **computed** on Race, never stored
2. `startedAt` is UTC Date — only convert to local timezone for UI display
3. `splitsPerLap` adjustable (1–4); domain logic uses it throughout
4. CADisplayLink **must** use `.common` run loop mode (not `.default`)
5. Elapsed time always recomputed from `startedAt`, never accumulated
6. RaceStateBlob persists BOTH unassigned marks AND undo stack
7. Each Split is saved to Core Data immediately on assignment

### TimingEngine Invariants
1. `unassignedMarks` sorted ascending by `timestampMs` at all times
2. `splitAssigned` undo: consumedMarkId in queue (undone) or gone (consumed), never both
3. `markCreated` undo: mark still present in `unassignedMarks`
4. `currentSplits` mirrors Core Data exactly
5. All mutations on main actor only, in `handleMarkTap`/`handleCardTap`

---

## SwiftUI Lessons Learned

### 1. NavigationLink in List/Form Rows
**Problem**: Inline `NavigationLink` inside a `List` or `Form` row takes over the ENTIRE row's tap gesture. Placing a `Button` alongside it causes tap conflicts.

**Fix**: Use state-based navigation:
```swift
@State private var profileAthlete: Athlete? = nil

Button { profileAthlete = athlete } label: { Image(systemName: "info.circle") }
    .buttonStyle(.plain)
    .contentShape(Rectangle())

.navigationDestination(isPresented: Binding(
    get: { profileAthlete != nil },
    set: { if !$0 { profileAthlete = nil } }
)) {
    if let athlete = profileAthlete { DestinationView(athlete: athlete) }
}
```

### 2. NavigationLink in Conditional @ViewBuilder
**Problem**: `NavigationLink` inside conditional `@ViewBuilder` content may fail silently — no navigation occurs.

**Fix**: Same as above — use `Button` + state + `.navigationDestination(isPresented:)`.

### 3. .navigationDestination(item:) — iOS 17+ Only
The `item:` overload is iOS 17+. For iOS 16, use `isPresented:` with a computed Binding from an optional.

### 4. .confirmationDialog vs .alert
- `.confirmationDialog` → action sheet at bottom (good for contextual menus)
- `.alert` → centered modal (better for deliberate destructive confirmations like "Finish Race?")

### 5. Gender Color Bars — Design Pattern
```swift
Rectangle()
    .fill(Theme.genderColor(athlete.gender))
    .frame(width: 4)
    .clipShape(Capsule())
```
- Male → `.blue`, Female → pink (`#FF5CA1`), nil → `quaternaryLabel`
- Paired with small color dot (athlete's assigned color) next to name

### 6. onTapGesture on Parent Intercepts Child Taps
**Problem**: `.onTapGesture` on an outer container intercepts ALL taps, including child Buttons.

**Fix**: Remove `.onTapGesture` from parent. Wrap tappable content in a `Button` with `.contentShape(Rectangle())`.

### 7. iOS 16 Deployment Target
Missing APIs to watch for:
- `.navigationDestination(item:)` (iOS 17)
- `@Observable` macro (iOS 17)
- `.scrollTargetBehavior` (iOS 17)

---

## Roadmap

### Near-Term (v1.4)
- [ ] **Cloud Sync** — iCloud Core Data sync for multi-device support
- [ ] **Meet Templates** — save meet configurations as reusable templates
- [ ] **Bulk Athlete Import** — CSV import for team rosters
- [ ] **Race Notes** — coaches can attach notes to individual races
- [ ] **Split Comparison** — overlay multiple race results for comparison analysis
- [ ] **Dark Mode Polish** — ensure all custom colors adapt properly

### Mid-Term (v1.5)
- [ ] **Runsmith Platform Integration** — sync data with the full Runsmith coaching platform
- [ ] **Live Sharing** — share live timing updates with parents/spectators
- [ ] **Apple Watch Companion** — mark splits from the wrist
- [ ] **Workout Builder** — create interval/tempo workout templates with target times
- [ ] **Season Analytics** — track athlete progression across the season with charts
- [ ] **Photo Finish** — attach photo evidence to close finishes

### Long-Term (v2.0)
- [ ] **iPad Layout** — multi-column layout optimized for iPad
- [ ] **Multi-Coach Mode** — multiple coaches timing different athletes simultaneously
- [ ] **Video Integration** — record video synced to split timestamps
- [ ] **AI Pace Analysis** — predict finish times based on early split patterns
- [ ] **Custom Event Builder** — define non-standard events (hurdles with split points, field events)
- [ ] **Team Scoring** — automatic dual meet and invitational scoring

### Known Issues / Technical Debt
- [ ] Quick Race history: races with `meetId==nil` not browsable after session ends
- [ ] Undo for `splitAssigned` reconstructs `UnassignedMark` with correct `timestampMs`
- [ ] `isIdleTimerDisabled` set in LiveTimingViewModel `onAppear`/`onDisappear`
- [ ] Scene phase background flush wired in LiveTimingView `.onChange(scenePhase)`

---

## Build & Run

```bash
# Generate Xcode project
cd "/Users/daniel/Documents/StreetTycoon/Runsmith Split Timer"
xcodegen generate

# Build via command line
xcodebuild -project RunsmithSplitTimer.xcodeproj \
  -scheme RunsmithSplitTimer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

---

*Built by Runsmith — Made for coaches, by coaches.*
*runsmith.com*
