import Foundation

/// Saves player progress as a single Codable snapshot with atomic writes.
///
/// Why not SwiftData for this: progress is one small document that must never be
/// half-written, must migrate predictably, and must be testable without a device.
/// An atomic JSON file + a rolling backup meets all three. SwiftData remains an
/// option for large, queryable data later (e.g. a per-round history log).
public final class ProgressStore {
    public let fileURL: URL
    private var backupURL: URL { fileURL.appendingPathExtension("bak") }

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static func defaultStore() throws -> ProgressStore {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
            .appendingPathComponent("WorldTrailsClub", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ProgressStore(fileURL: dir.appendingPathComponent("progress.json"))
    }

    /// Returns saved progress, falling back to the backup if the main file is corrupt,
    /// and to fresh progress if nothing exists.
    public func load() -> PlayerProgress {
        for url in [fileURL, backupURL] {
            if let data = try? Data(contentsOf: url),
               let progress = try? Self.decoder.decode(PlayerProgress.self, from: data) {
                return progress
            }
        }
        return PlayerProgress()
    }

    public func save(_ progress: PlayerProgress) throws {
        let data = try Self.encoder.encode(progress)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }
        try data.write(to: fileURL, options: [.atomic])
    }

    public func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: backupURL)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
