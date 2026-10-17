import Foundation

public struct ContentIssue: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let itemID: String
    public let message: String
    public var description: String { "[\(itemID)] \(message)" }
}

/// Guards against the content bugs that ruin a clue game: answer leaks,
/// duplicates, broken unlock graphs, and impossible coordinates.
public enum ContentValidator {
    public static let requiredClueCount = 5

    public static func validate(_ pack: ContentPack) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let countryIDs = Set(pack.countries.map(\.id))

        // Unique ids
        var seenCountryIDs = Set<String>()
        for c in pack.countries where !seenCountryIDs.insert(c.id).inserted {
            issues.append(ContentIssue(itemID: c.id, message: "duplicate country id"))
        }
        var seenDestinationIDs = Set<String>()
        for d in pack.destinations where !seenDestinationIDs.insert(d.id).inserted {
            issues.append(ContentIssue(itemID: d.id, message: "duplicate destination id"))
        }

        // Countries
        for c in pack.countries {
            for dep in c.unlockAfter where !countryIDs.contains(dep) {
                issues.append(.init(itemID: c.id, message: "unlockAfter references unknown country \(dep)"))
            }
            if pack.destinations(in: c.id).isEmpty {
                issues.append(.init(itemID: c.id, message: "country has no destinations"))
            }
        }
        if !pack.countries.contains(where: { $0.unlockAfter.isEmpty && !$0.isPlusCollection }) {
            issues.append(.init(itemID: "pack", message: "no free starting country"))
        }
        if hasUnlockCycle(pack.countries) {
            issues.append(.init(itemID: "pack", message: "unlock graph contains a cycle"))
        }

        // Destinations
        var seenClues: [String: String] = [:]
        for d in pack.destinations {
            if !countryIDs.contains(d.countryID) {
                issues.append(.init(itemID: d.id, message: "unknown country \(d.countryID)"))
            }
            if d.clues.count != requiredClueCount {
                issues.append(.init(itemID: d.id, message: "expected \(requiredClueCount) clues, found \(d.clues.count)"))
            }
            if !(-90...90).contains(d.latitude) || !(-180...180).contains(d.longitude) {
                issues.append(.init(itemID: d.id, message: "coordinates out of range"))
            }
            if !(1...3).contains(d.difficulty) {
                issues.append(.init(itemID: d.id, message: "difficulty must be 1...3"))
            }
            if d.fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(itemID: d.id, message: "missing fact"))
            }
            // Answer leakage: no clue may contain the destination name or an alias.
            let forbidden = ([d.name] + d.aliases).map(normalize).filter { $0.count >= 3 }
            for (i, clue) in d.clues.enumerated() {
                let text = normalize(clue.text)
                if text.isEmpty {
                    issues.append(.init(itemID: d.id, message: "clue \(i + 1) is empty"))
                }
                if forbidden.contains(where: { containsWord(text, $0) }) {
                    issues.append(.init(itemID: d.id, message: "clue \(i + 1) leaks the answer"))
                }
                if let other = seenClues[text] {
                    issues.append(.init(itemID: d.id, message: "clue \(i + 1) duplicates a clue in \(other)"))
                } else {
                    seenClues[text] = d.id
                }
            }
        }
        // Gazetteer (decoy guesses)
        let destinationIDs = Set(pack.destinations.map(\.id))
        var gazetteerIDs = Set<String>()
        for p in pack.gazetteer {
            if destinationIDs.contains(p.id) || !gazetteerIDs.insert(p.id).inserted {
                issues.append(.init(itemID: p.id, message: "duplicate place id"))
            }
            if !(-90...90).contains(p.latitude) || !(-180...180).contains(p.longitude) {
                issues.append(.init(itemID: p.id, message: "coordinates out of range"))
            }
        }
        return issues
    }

    public static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whole-word containment so "Rome" doesn't flag "Romeo", but "Rome" does flag "Rome's".
    static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let r = haystack.range(of: needle, range: searchRange) {
            let beforeOK = r.lowerBound == haystack.startIndex || !haystack[haystack.index(before: r.lowerBound)].isLetter
            let afterOK = r.upperBound == haystack.endIndex || !haystack[r.upperBound].isLetter
            if beforeOK && afterOK { return true }
            searchRange = r.upperBound..<haystack.endIndex
        }
        return false
    }

    static func hasUnlockCycle(_ countries: [Country]) -> Bool {
        let edges = Dictionary(countries.map { ($0.id, $0.unlockAfter) }, uniquingKeysWith: { a, b in a + b })
        var visiting = Set<String>(), done = Set<String>()
        func visit(_ id: String) -> Bool {
            if done.contains(id) { return false }
            if visiting.contains(id) { return true }
            visiting.insert(id)
            for dep in edges[id] ?? [] where visit(dep) { return true }
            visiting.remove(id)
            done.insert(id)
            return false
        }
        return countries.contains { visit($0.id) }
    }
}
