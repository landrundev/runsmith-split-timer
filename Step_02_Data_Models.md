# Step 02 â Create SharedRaceConfig and CoachSplitPayload Data Models

---

## CREATE `SplitDeck/Models/SharedRaceConfig.swift`

```swift
import Foundation

/// Shared from host coach â assistant coaches before the race starts.
/// Contains the full race setup and athlete list with stable UUIDs.
struct SharedRaceConfig: Codable {
    let version: Int           // Schema version â always 1 for now
    let configId: UUID         // Unique ID linking this config to its CoachSplitPayloads
    let hostCoachName: String  // Display name of the host coach, e.g. "Coach Davis"

    // Race configuration
    let raceName: String
    let eventType: EventType
    let distanceMeters: Int
    let trackLengthMeters: Int
    let splitsPerLap: Int
    let isUnlimitedSplits: Bool

    // Athlete list â UUIDs must match the host's Core Data athlete IDs
    let athletes: [SharedAthlete]
}

/// A lightweight athlete record for embedding in SharedRaceConfig.
/// The `id` is the host's canonical UUID for this athlete â assistant coaches
/// use it to create a matching local athlete so post-race split payloads
/// can be merged by UUID without any name-matching.
struct SharedAthlete: Codable, Identifiable {
    let id: UUID
    let name: String
    let gender: Gender?
    let colorHex: String
}
```

---

## CREATE `SplitDeck/Models/CoachSplitPayload.swift`

```swift
import Foundation

/// Sent from an assistant coach â host coach after the race ends.
/// Athlete IDs match SharedRaceConfig.athletes[n].id â no name-matching needed.
struct CoachSplitPayload: Codable {
    let version: Int           // Schema version â always 1 for now
    let configId: UUID         // Links back to SharedRaceConfig.configId
    let coachName: String      // Display name of the exporting coach, e.g. "Coach Williams"
    let exportedAt: Date       // Timestamp of export
    let athleteSplits: [AthleteTimingData]
}

/// Split data for a single athlete, keyed by the shared UUID.
/// `splits` is an ordered array of elapsedMs values, one per split ordinal
/// (same ordering as the host's Split entities sorted by lapIndex).
struct AthleteTimingData: Codable {
    let athleteId: UUID   // Matches SharedAthlete.id / host's Athlete.id
    let splits: [Int]     // elapsedMs values in lap order
}
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `SharedRaceConfig` can be instantiated in an Xcode Preview or unit test with sample data
- [ ] `CoachSplitPayload` can be instantiated in an Xcode Preview or unit test with sample data
- [ ] `JSONEncoder().encode(sampleConfig)` produces valid JSON data without throwing
- [ ] `JSONDecoder().decode(SharedRaceConfig.self, from: data)` round-trips back to an equal struct
- [ ] `JSONEncoder().encode(samplePayload)` produces valid JSON data without throwing
- [ ] `JSONDecoder().decode(CoachSplitPayload.self, from: data)` round-trips back to an equal struct
- [ ] `SharedAthlete` conforms to `Identifiable` (use `id` in a `ForEach` in a preview to confirm)
- [ ] A `SharedRaceConfig` with `athletes: []` encodes and decodes without errors
- [ ] A `CoachSplitPayload` with `athleteSplits: []` encodes and decodes without errors

### Sample data for manual verification

```swift
// Paste into a Preview or Playground to verify round-trip

let config = SharedRaceConfig(
    version: 1,
    configId: UUID(),
    hostCoachName: "Coach Davis",
    raceName: "Boys 800m â Heat 1",
    eventType: .mens800m,          // Use any valid EventType rawValue in your project
    distanceMeters: 800,
    trackLengthMeters: 400,
    splitsPerLap: 1,
    isUnlimitedSplits: false,
    athletes: [
        SharedAthlete(id: UUID(), name: "Jake Miller", gender: .male, colorHex: "#FF3B30"),
        SharedAthlete(id: UUID(), name: "Sarah Chen", gender: .female, colorHex: "#007AFF")
    ]
)

let configData = try! JSONEncoder().encode(config)
let decoded = try! JSONDecoder().decode(SharedRaceConfig.self, from: configData)
assert(decoded.configId == config.configId)
assert(decoded.athletes.count == 2)

let payload = CoachSplitPayload(
    version: 1,
    configId: config.configId,
    coachName: "Coach Williams",
    exportedAt: Date(),
    athleteSplits: [
        AthleteTimingData(athleteId: config.athletes[0].id, splits: [28320, 58410]),
        AthleteTimingData(athleteId: config.athletes[1].id, splits: [29100, 59800])
    ]
)

let payloadData = try! JSONEncoder().encode(payload)
let decodedPayload = try! JSONDecoder().decode(CoachSplitPayload.self, from: payloadData)
assert(decodedPayload.configId == payload.configId)
assert(decodedPayload.athleteSplits[0].splits == [28320, 58410])
```
