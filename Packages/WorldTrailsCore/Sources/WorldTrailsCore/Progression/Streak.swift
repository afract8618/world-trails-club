import Foundation

/// Converts dates to stable local day numbers so streaks follow the player's calendar.
public struct DayClock: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) { self.calendar = calendar }

    /// Days since 2000-01-01 in the calendar's time zone.
    public func dayNumber(for date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        let c = calendar.dateComponents([.year, .month, .day], from: start)
        // Julian-day style counting from components avoids DST hour drift.
        let y = c.year!, m = c.month!, d = c.day!
        let a = (14 - m) / 12
        let yy = y + 4800 - a
        let mm = m + 12 * a - 3
        let jdn = d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
        return jdn - 2_451_545 // 2000-01-01
    }

    public func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

/// A forgiving streak: missing a day spends a "Rest Day" token instead of resetting.
/// Tokens are earned (one per 7 streak days, max 2), never sold.
public struct Streak: Codable, Equatable, Sendable {
    public var current = 0
    public var best = 0
    public var lastDay: Int?
    public var restTokens = 1
    public static let maxRestTokens = 2
    public static let daysPerToken = 7

    public init() {}

    public enum Outcome: Equatable, Sendable {
        case alreadyCountedToday
        case started
        case extended
        case savedByRestTokens(Int)
        case restarted(previous: Int)
    }

    /// Call when the player completes a qualifying activity (the Daily Expedition).
    @discardableResult
    public mutating func record(day: Int) -> Outcome {
        defer { best = max(best, current) }
        guard let last = lastDay else {
            current = 1; lastDay = day
            return .started
        }
        if day <= last { return .alreadyCountedToday }

        let missed = day - last - 1
        let outcome: Outcome
        if missed == 0 {
            current += 1
            outcome = .extended
        } else if missed <= restTokens {
            restTokens -= missed
            current += 1
            outcome = .savedByRestTokens(missed)
        } else {
            let previous = current
            current = 1
            outcome = .restarted(previous: previous)
        }
        lastDay = day
        if current > 0, current % Self.daysPerToken == 0 {
            restTokens = min(Self.maxRestTokens, restTokens + 1)
        }
        return outcome
    }

    /// Streak value to display today (doesn't mutate). Shows 0 only if the streak is unrecoverable.
    public func displayValue(today: Int) -> Int {
        guard let last = lastDay else { return 0 }
        let missed = today - last - 1
        return missed <= restTokens ? current : 0
    }
}
