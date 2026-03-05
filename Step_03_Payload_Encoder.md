# Step 03 â Create PayloadEncoder for JSON and QR Code Encoding/Decoding

**Depends on**: `SharedRaceConfig.swift` and `CoachSplitPayload.swift` from Step 02 must already be in the project.

---

## CREATE `SplitDeck/Domain/PayloadEncoder.swift`

```swift
import Foundation

enum PayloadEncoder {

    // MARK: â SharedRaceConfig JSON

    /// Encode a SharedRaceConfig to JSON data for file sharing (AirDrop, iMessage, etc.).
    static func encodeJSON(_ config: SharedRaceConfig) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(config)
    }

    /// Decode a SharedRaceConfig from JSON data.
    static func decodeRaceConfig(from data: Data) -> SharedRaceConfig? {
        try? JSONDecoder().decode(SharedRaceConfig.self, from: data)
    }

    // MARK: â CoachSplitPayload JSON

    /// Encode a CoachSplitPayload to JSON data for file sharing (AirDrop, iMessage, etc.).
    static func encodeJSON(_ payload: CoachSplitPayload) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(payload)
    }

    /// Decode a CoachSplitPayload from JSON data.
    static func decodeSplitPayload(from data: Data) -> CoachSplitPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CoachSplitPayload.self, from: data)
    }

    // MARK: â QR Code (zlib-compressed base64)

    /// Encode any Codable value to a compact string suitable for a QR code.
    /// Process: JSON encode â zlib compress â base64 encode.
    /// Falls back to uncompressed base64 if compression fails.
    static func encodeForQR<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(value) else { return nil }

        if let compressed = try? (json as NSData).compressed(using: .zlib) as Data {
            return compressed.base64EncodedString()
        }

        // Compression unavailable â fall back to uncompressed base64
        return json.base64EncodedString()
    }

    /// Decode a QR string back to the specified Decodable type.
    /// Tries zlib-decompressed JSON first, then falls back to direct base64-decoded JSON.
    static func decodeFromQR<T: Decodable>(_ string: String, as type: T.Type) -> T? {
        guard let data = Data(base64Encoded: string) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try decompressed first
        if let decompressed = try? (data as NSData).decompressed(using: .zlib) as Data,
           let decoded = try? decoder.decode(T.self, from: decompressed) {
            return decoded
        }

        // Fall back to direct decode (handles uncompressed base64 fallback from encodeForQR)
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: â QR Type Detection

    /// Represents the two payload types that can be encoded in a QR code.
    enum QRContent {
        case raceConfig(SharedRaceConfig)
        case splitPayload(CoachSplitPayload)
    }

    /// Attempt to decode a scanned QR string as either a SharedRaceConfig or a
    /// CoachSplitPayload. Returns whichever succeeds, or nil if neither matches.
    static func decodeQR(_ string: String) -> QRContent? {
        if let config = decodeFromQR(string, as: SharedRaceConfig.self) {
            return .raceConfig(config)
        }
        if let payload = decodeFromQR(string, as: CoachSplitPayload.self) {
            return .splitPayload(payload)
        }
        return nil
    }
}
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `PayloadEncoder.encodeJSON(_:)` for `SharedRaceConfig` returns non-nil `Data`
- [ ] `PayloadEncoder.decodeRaceConfig(from:)` round-trips the encoded data back to an equal struct (same `configId`, same `athletes.count`)
- [ ] `PayloadEncoder.encodeJSON(_:)` for `CoachSplitPayload` returns non-nil `Data`
- [ ] `PayloadEncoder.decodeSplitPayload(from:)` round-trips the encoded data back to an equal struct (same `configId`, same `athleteSplits[0].splits`)
- [ ] `PayloadEncoder.encodeForQR(_:)` for `SharedRaceConfig` returns a non-nil, non-empty `String`
- [ ] `PayloadEncoder.decodeFromQR(_:as:)` for `SharedRaceConfig` round-trips to an equal struct
- [ ] `PayloadEncoder.encodeForQR(_:)` for `CoachSplitPayload` returns a non-nil, non-empty `String`
- [ ] `PayloadEncoder.decodeFromQR(_:as:)` for `CoachSplitPayload` round-trips to an equal struct
- [ ] `PayloadEncoder.decodeQR(_:)` returns `.raceConfig` when given a QR-encoded `SharedRaceConfig` string
- [ ] `PayloadEncoder.decodeQR(_:)` returns `.splitPayload` when given a QR-encoded `CoachSplitPayload` string
- [ ] `PayloadEncoder.decodeQR(_:)` returns `nil` for a garbage / random string
- [ ] The QR string for a `SharedRaceConfig` with 8 athletes is under 1500 characters (fits comfortably in a QR code)

### Sample data for manual verification

```swift
// Paste into a Preview or Playground to verify all paths

let athleteId1 = UUID()
let athleteId2 = UUID()
let configId = UUID()

let config = SharedRaceConfig(
    version: 1,
    configId: configId,
    hostCoachName: "Coach Davis",
    raceName: "Boys 800m â Heat 1",
    eventType: .mens800m,  // substitute a valid EventType case in your project
    distanceMeters: 800,
    trackLengthMeters: 400,
    splitsPerLap: 1,
    isUnlimitedSplits: false,
    athletes: [
        SharedAthlete(id: athleteId1, name: "Jake Miller", gender: .male, colorHex: "#FF3B30"),
        SharedAthlete(id: athleteId2, name: "Sarah Chen", gender: .female, colorHex: "#007AFF")
    ]
)

// JSON round-trip
let configJSON = PayloadEncoder.encodeJSON(config)!
let configDecoded = PayloadEncoder.decodeRaceConfig(from: configJSON)!
assert(configDecoded.configId == configId)
assert(configDecoded.athletes.count == 2)

// QR round-trip
let configQR = PayloadEncoder.encodeForQR(config)!
print("Config QR string length: \(configQR.count)")  // Should be well under 1500
let configFromQR = PayloadEncoder.decodeFromQR(configQR, as: SharedRaceConfig.self)!
assert(configFromQR.configId == configId)

// decodeQR type detection for config
if case .raceConfig(let c) = PayloadEncoder.decodeQR(configQR) {
    assert(c.configId == configId)
} else { fatalError("Expected .raceConfig") }

let payload = CoachSplitPayload(
    version: 1,
    configId: configId,
    coachName: "Coach Williams",
    exportedAt: Date(),
    athleteSplits: [
        AthleteTimingData(athleteId: athleteId1, splits: [28320, 58410]),
        AthleteTimingData(athleteId: athleteId2, splits: [29100, 59800])
    ]
)

// JSON round-trip
let payloadJSON = PayloadEncoder.encodeJSON(payload)!
let payloadDecoded = PayloadEncoder.decodeSplitPayload(from: payloadJSON)!
assert(payloadDecoded.configId == configId)
assert(payloadDecoded.athleteSplits[0].splits == [28320, 58410])

// QR round-trip
let payloadQR = PayloadEncoder.encodeForQR(payload)!
let payloadFromQR = PayloadEncoder.decodeFromQR(payloadQR, as: CoachSplitPayload.self)!
assert(payloadFromQR.coachName == "Coach Williams")

// decodeQR type detection for payload
if case .splitPayload(let p) = PayloadEncoder.decodeQR(payloadQR) {
    assert(p.configId == configId)
} else { fatalError("Expected .splitPayload") }

// Garbage string returns nil
assert(PayloadEncoder.decodeQR("not-a-valid-qr-payload") == nil)
```
