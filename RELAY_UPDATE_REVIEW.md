# Relay Feature Update — Code Review (Build 25)

## Overview

Three relay-related changes were made in this update. This document covers what changed, why, what to watch for during testing, and architectural notes for future work.

---

## Change 1: Relay Display Names & Leg Distances

### Problem
The relay enum cases are named by **total relay distance** (e.g., `relay4x400` = 400m total). However, `displayName` and `legDistanceMeters` were incorrectly returning the *total* distance as if it were the *leg* distance:

| Enum Case | Old Display | Old legDistance | Correct Display | Correct legDistance |
|-----------|-------------|----------------|-----------------|---------------------|
| `relay4x400` | 4x400m | 400 | **4x100m** | **100** |
| `relay4x800` | 4x800m | 800 | **4x200m** | **200** |
| `relay4x1600` | 4x1600m | 1600 | **4x400m** | **400** |
| `relay4x3200` | 4x3200m | 3200 | **4x800m** | **800** |

### Files Changed
- **`SplitDeck/Models/Race.swift`** — `displayName` and `legDistanceMeters` computed properties

### How It Works
The `EventType` raw values (Int16) are unchanged — no Core Data migration needed. `displayName` and `legDistanceMeters` are computed, so all UI updates automatically.

### Impact on Race Creation
In `RaceSetupViewModel.buildRaceFields()`, relay races set both `distanceMeters` and `trackLengthMeters` to `legDistanceMeters`:

```swift
if eventType.isRelay {
    let legDist = eventType.legDistanceMeters!
    dist  = legDist   // distanceMeters
    track = legDist   // trackLengthMeters
}
```

This means `laps = dist / track = 1` — each athlete records exactly 1 split (their leg). This is **unchanged behavior**; only the numeric values fed in are now correct.

### Backward Compatibility
Existing saved races have `distanceMeters = 400` and `trackLengthMeters = 400` for what is now displayed as a 4x100m relay. Since `laps = 400/400 = 1`, the split count remains correct. No data migration is needed.

New races created after this update will have `distanceMeters = 100` and `trackLengthMeters = 100` for a 4x100m relay. `laps = 100/100 = 1`. Same behavior.

### Where `legDistanceMeters` Is Used (audit)
| File | Usage | Status |
|------|-------|--------|
| `Race.swift` | `defaultDistance` fallback for relays | OK — returns leg distance |
| `RaceSetupViewModel.swift` | `buildRaceFields()`, `buildSharedConfig()` | OK — sets track = legDist |
| `RaceSetupView.swift` | "4 runners x Xm" format label | OK — shows correct leg distance |
| `RelayBuilderViewModel.swift` | `legDistanceDisplay`, race creation | OK — dynamic |
| `RelayRecommender.swift` | Matching individual race distances to leg distances | OK — dynamic |

No hardcoded relay name strings ("4x400m", etc.) exist outside `displayName`.

---

## Change 2: Cumulative/Lap Times Toggle on Relay Results

### Problem
Individual race results had a segmented `Picker` to toggle between Cumulative and Lap Times display. Relay results did not — they always showed both columns side by side.

### Files Changed
- **`SplitDeck/Views/Results/ResultsView.swift`** — moved Picker outside the relay/individual branch; updated `relayResultsTable` to respect `displayMode`

### What Changed

**Before:**
```
[Picker] — only for individual
[relay table showing: Leg | Athlete | Leg Time | Cumulative]
```

**After:**
```
[Picker] — always shown
[relay table showing: Leg | Athlete | (Leg Time OR Cumulative based on toggle)]
```

When `displayMode == .lapTimes`: shows Leg Time column (delta per leg)
When `displayMode == .cumulative`: shows Cumulative column (elapsed from race start)

The column header text updates dynamically: "Leg Time" vs "Cumulative". Column width is 90pt (slightly wider than before to accommodate both label variants).

### Share Card Note
The share card (`CardRenderer.swift` + `ResultsCardView.swift`) still renders **both** columns (Leg Time + Cumulative) regardless of the toggle. The toggle only affects the interactive ResultsView. If you want the share card to also respect the toggle, `buildCardData()` in `ResultsViewModel` would need to pass `displayMode` through to the relay card rendering logic. This was intentionally left as-is since the share card has more space and showing both columns is useful for sharing.

### Architecture Note
`ResultsViewModel.displayMode` is `@Published` and drives both individual and relay display. The `relayLegData` tuple already contains both `legMs` and `cumulativeMs`, so the view simply picks which one to render.

---

## Change 3: Split + Cumulative Times on Relay Live Timing

### Problem
During live timing, completed relay legs only showed the cumulative elapsed time (time from race start). Coaches wanted to see the **leg split time** (how long that specific leg took) alongside the cumulative.

### Files Changed
- **`SplitDeck/ViewModels/LiveTimingViewModel.swift`** — added `relayLegDelta(legIndex:)` method
- **`SplitDeck/Views/LiveTiming/LiveTimingView.swift`** — updated `relayLegRow` for completed legs

### New VM Method
```swift
func relayLegDelta(legIndex: Int) -> Int? {
    guard isRelay, legIndex < race.athleteIds.count else { return nil }
    let athleteId = race.athleteIds[legIndex]
    guard let cumulative = splits.first(where: { $0.athleteId == athleteId })?.elapsedMs
        else { return nil }
    let prevCumulative: Int
    if legIndex > 0 {
        prevCumulative = splits.first(where: {
            $0.athleteId == race.athleteIds[legIndex - 1]
        })?.elapsedMs ?? 0
    } else {
        prevCumulative = 0
    }
    return cumulative - prevCumulative
}
```

This mirrors the same logic in `RaceDomain.relayLegData()` but is callable per-leg from the view.

### Display Format
Completed legs now show:
```
[Leg Delta]  (Cumulative)
 0:58.32     (1:56.14)
```

- Leg delta: `.caption.weight(.semibold).monospacedDigit()`, secondary color
- Cumulative: `.caption2.monospacedDigit()`, tertiary color, in parentheses

### Edge Cases
- **Leg 1**: `prevCumulative = 0`, so delta == cumulative (both show same time)
- **Leg reorder mid-race**: `race.athleteIds` order may change via `moveRelayLeg()`. The delta calculation uses `race.athleteIds[legIndex - 1]` to find the previous leg's athlete, which is correct even after reordering since `athleteIds` tracks the authoritative leg order.

---

## Testing Checklist

### Display Names
- [ ] Create a relay race for each type (4x100m, 4x200m, 4x400m, 4x800m) — verify picker shows correct names
- [ ] Check RaceSetupView "Format" label shows correct leg distance (e.g., "4 runners x 100m")
- [ ] Check relay builder shows correct event names
- [ ] Open an **existing** relay race saved before this update — verify display name updated retroactively
- [ ] Check `lapSubtitle` during live timing shows correct relay name (e.g., "4x100m — Leg 2 of 4: Smith")
- [ ] Check results header shows correct event type
- [ ] Check share card header shows correct event type

### Results Toggle
- [ ] Open relay results — verify segmented picker (Cumulative / Lap Times) appears above the table
- [ ] Toggle to "Cumulative" — verify column shows elapsed time from race start for each leg
- [ ] Toggle to "Lap Times" — verify column shows delta (time for that specific leg)
- [ ] Verify Total row always shows total elapsed time regardless of toggle
- [ ] Open individual results — verify picker still works as before
- [ ] Share relay results as image — verify share card still shows both columns (not affected by toggle)

### Live Timing Split Display
- [ ] Start a relay race, record Leg 1 — verify completed row shows: `delta (cumulative)`. For Leg 1, both values should be identical
- [ ] Record Leg 2 — verify delta is `Leg2_cumulative - Leg1_cumulative`, cumulative is total elapsed
- [ ] Record all 4 legs — verify all rows show correct delta + cumulative pairs
- [ ] Reorder legs mid-race (drag), then record — verify times still compute correctly
- [ ] Verify "Tap to record split" still shows for current leg
- [ ] Verify "Waiting" still shows for future legs

### Regression
- [ ] Individual race timing — no changes expected, verify unaffected
- [ ] Unlimited splits race — verify unaffected
- [ ] Quick Race + Meet Race relay creation both work
- [ ] Relay builder "Start Race" works with corrected leg distances
- [ ] CSV export for relay races — verify correct event name in output
- [ ] Multi-coach export/import for relay — verify `SharedRaceConfig` uses correct `trackLengthMeters`

---

## Architecture Notes for Future Dev

### EventType Enum Convention
The enum cases are named by **total relay distance** (`relay4x400` = 400m total, displayed as "4x100m"). This is a legacy naming choice. The cases cannot be renamed without breaking Core Data raw values. When adding new relay types, follow the same convention: `relay4xTOTAL` with `legDistanceMeters` returning `TOTAL / 4`.

### Relay Data Flow
```
RaceDomain.relayLegData()          — pure function, computes (leg, athlete, legMs, cumulativeMs)
  ├── ResultsViewModel.relayLegData    — exposes to ResultsView
  ├── ResultsViewModel.buildCardData() — maps to CardData.CardRelayLeg
  └── LiveTimingViewModel             — own delta calc via relayLegDelta()
```

`RaceDomain.relayLegData()` is the source of truth for results. `LiveTimingViewModel.relayLegDelta()` is a separate calculation for live timing (same logic, different entry point since it needs per-leg access during the race).

### Split Storage for Relays
Each relay leg stores one `Split` with `elapsedMs` = cumulative time from race start. The delta (leg time) is always computed, never stored. Athletes are identified by position in `race.athleteIds` array (index 0 = Leg 1).

### Share Card vs Interactive View
The share card (`CardRenderer.swift`) always renders both Leg Time and Cumulative columns for relay results. The interactive `ResultsView` now toggles between them. If a future request asks the share card to match the toggle, update `CardData` to include `displayMode` and branch in `drawRelayContent()`.

### Key Files Reference
| File | Role |
|------|------|
| `SplitDeck/Models/Race.swift` | EventType enum, display names, leg distances |
| `SplitDeck/Domain/RaceDomain.swift` | Pure relay leg computation |
| `SplitDeck/ViewModels/LiveTimingViewModel.swift` | Live timing relay state + `relayLegDelta()` |
| `SplitDeck/Views/LiveTiming/LiveTimingView.swift` | Relay live timing UI (leg rows, bottom bar) |
| `SplitDeck/ViewModels/ResultsViewModel.swift` | Results data + `relayLegData` passthrough |
| `SplitDeck/Views/Results/ResultsView.swift` | Results UI + toggle |
| `SplitDeck/Views/Results/CardRenderer.swift` | Core Graphics share card (relay section) |
| `SplitDeck/Views/Results/ResultsCardView.swift` | SwiftUI card data model + preview |
| `SplitDeck/ViewModels/RaceSetupViewModel.swift` | Race creation with `legDistanceMeters` |
| `SplitDeck/Domain/RelayRecommender.swift` | Relay team recommendations by leg distance |
