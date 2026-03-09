import Foundation
import UniformTypeIdentifiers

enum PayloadEncoder {

    // MARK: – SharedRaceConfig JSON

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

    // MARK: – SharedMeetConfig JSON

    /// Encode a SharedMeetConfig to JSON data for file sharing.
    static func encodeJSON(_ config: SharedMeetConfig) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(config)
    }

    /// Decode a SharedMeetConfig from JSON data.
    static func decodeMeetConfig(from data: Data) -> SharedMeetConfig? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedMeetConfig.self, from: data)
    }

    // MARK: – CoachSplitPayload JSON

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

    // MARK: – CoachMeetPayload JSON

    /// Encode a CoachMeetPayload to JSON data.
    static func encodeJSON(_ payload: CoachMeetPayload) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try? encoder.encode(payload)
    }

    /// Decode a CoachMeetPayload from JSON data.
    static func decodeMeetPayload(from data: Data) -> CoachMeetPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CoachMeetPayload.self, from: data)
    }

    // MARK: – .runsmith File Type

    /// Custom UTType for `.runsmith` files.
    static let runsmithType = UTType(exportedAs: "com.runsmith.splitdeck.timing-data")

    /// Writes a CoachMeetPayload to a temporary `.runsmith` file for sharing.
    static func writeRunsmithFile(_ payload: CoachMeetPayload, meetName: String) -> URL? {
        guard let data = encodeJSON(payload) else { return nil }
        let safeName = meetName
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeName)-timing-data.runsmith"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    /// Reads a `.runsmith` file URL and decodes the CoachMeetPayload.
    static func readRunsmithFile(at url: URL) -> CoachMeetPayload? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decodeMeetPayload(from: data)
    }

    // MARK: – QR Code (zlib-compressed base64)

    /// Encode any Codable value to a compact string suitable for a QR code.
    /// Process: JSON encode → zlib compress → base64 encode.
    /// Falls back to uncompressed base64 if compression fails.
    static func encodeForQR<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(value) else { return nil }

        if let compressed = try? (json as NSData).compressed(using: .zlib) as Data {
            return compressed.base64EncodedString()
        }

        // Compression unavailable — fall back to uncompressed base64
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

    // MARK: – QR Type Detection

    /// Represents the payload types that can be encoded in a QR code.
    enum QRContent {
        case raceConfig(SharedRaceConfig)
        case meetConfig(SharedMeetConfig)
        case splitPayload(CoachSplitPayload)
        case meetPayload(CoachMeetPayload)
    }

    /// Attempt to decode a scanned QR string as one of the known payload types.
    /// Returns whichever succeeds, or nil if none match.
    /// Tries most-specific types first to avoid false positives.
    static func decodeQR(_ string: String) -> QRContent? {
        // Try most-specific types first
        if let meetPayload = decodeFromQR(string, as: CoachMeetPayload.self),
           !meetPayload.racePayloads.isEmpty {
            return .meetPayload(meetPayload)
        }
        if let meetConfig = decodeFromQR(string, as: SharedMeetConfig.self) {
            return .meetConfig(meetConfig)
        }
        if let config = decodeFromQR(string, as: SharedRaceConfig.self) {
            return .raceConfig(config)
        }
        if let payload = decodeFromQR(string, as: CoachSplitPayload.self) {
            return .splitPayload(payload)
        }
        return nil
    }
}
