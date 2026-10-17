import Foundation
import OSLog
import WorldTrailsCore

/// Debug sink: writes events to the unified log (filter by subsystem in Console.app).
/// Replace or supplement with a vendor adapter (e.g. TelemetryDeck, PostHog, Firebase)
/// that forwards `AnalyticsRecord`s — the event schema stays the same.
final class LogAnalyticsSink: AnalyticsSink {
    private let logger = Logger(subsystem: "WorldTrailsClub", category: "analytics")

    func send(_ record: AnalyticsRecord) {
        let params = record.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.debugText)" }
            .joined(separator: " ")
        logger.debug("\(record.name, privacy: .public) \(params, privacy: .public)")
    }
}

private extension AnalyticsValue {
    var debugText: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .bool(let b): return b ? "true" : "false"
        }
    }
}
