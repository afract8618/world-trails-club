import Foundation

/// A broad world region. Used for map framing and recommendations.
public enum Region: String, Codable, CaseIterable, Sendable {
    case eastAsia, europe, northAmerica, southAmerica, africa, middleEast, oceania, southAsia
}

/// What a clue is about. Drives the icon shown next to the clue card.
public enum ClueKind: String, Codable, CaseIterable, Sendable {
    case geography, nature, culture, food, history, landmark
}

public struct Clue: Codable, Hashable, Sendable {
    public let kind: ClueKind
    public let text: String

    public init(kind: ClueKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// A country is a "trail": a set of destinations that, once all stamped,
/// completes the trail and unlocks the next countries on the world map.
public struct Country: Codable, Hashable, Identifiable, Sendable {
    public let id: String            // e.g. "jp"
    public let name: String          // e.g. "Japan"
    public let region: Region
    public let latitude: Double
    public let longitude: Double
    /// Country ids that must be completed before this one unlocks.
    /// Empty = available from the start.
    public let unlockAfter: [String]
    /// Optional content gating for World Trails Club Plus collections.
    /// Core trails are never gated.
    public let isPlusCollection: Bool

    public init(id: String, name: String, region: Region, latitude: Double, longitude: Double,
                unlockAfter: [String] = [], isPlusCollection: Bool = false) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.unlockAfter = unlockAfter
        self.isPlusCollection = isPlusCollection
    }
}

/// A single mystery destination. Clues are ordered hardest → easiest.
public struct Destination: Codable, Hashable, Identifiable, Sendable {
    public let id: String            // e.g. "jp-kyoto"
    public let name: String          // e.g. "Kyoto"
    public let countryID: String
    public let latitude: Double
    public let longitude: Double
    /// 1 = well known, 2 = moderate, 3 = deep cut.
    public let difficulty: Int
    public let clues: [Clue]
    /// Shown on the results card after the round.
    public let fact: String
    /// Alternate accepted names (search matching only, never shown as clues).
    public let aliases: [String]

    public init(id: String, name: String, countryID: String, latitude: Double, longitude: Double,
                difficulty: Int, clues: [Clue], fact: String, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.countryID = countryID
        self.latitude = latitude
        self.longitude = longitude
        self.difficulty = difficulty
        self.clues = clues
        self.fact = fact
        self.aliases = aliases
    }

    public var coordinate: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}

/// Anything the player can type as a guess. The guess pool is much larger than
/// the answer pool (a world gazetteer) so rounds can't be solved by elimination.
public struct Place: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let countryName: String
    public let latitude: Double
    public let longitude: Double
    public let aliases: [String]

    public init(id: String, name: String, countryName: String, latitude: Double, longitude: Double, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.countryName = countryName
        self.latitude = latitude
        self.longitude = longitude
        self.aliases = aliases
    }

    public var coordinate: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}

/// The full content set the app ships with (or downloads later).
/// Versioned so live-ops packs can be layered on without an app update.
public struct ContentPack: Codable, Sendable {
    public let version: Int
    public let countries: [Country]
    public let destinations: [Destination]
    /// Extra guessable places that are never answers.
    public let gazetteer: [Place]

    public init(version: Int, countries: [Country], destinations: [Destination], gazetteer: [Place] = []) {
        self.version = version
        self.countries = countries
        self.destinations = destinations
        self.gazetteer = gazetteer
    }

    public func place(for destination: Destination) -> Place {
        Place(id: destination.id, name: destination.name,
              countryName: country(destination.countryID)?.name ?? "",
              latitude: destination.latitude, longitude: destination.longitude,
              aliases: destination.aliases)
    }

    /// Every guessable place: all destinations plus the gazetteer, de-duplicated by name+country.
    public var guessPool: [Place] {
        var seen = Set<String>()
        var result: [Place] = []
        for p in destinations.map(place(for:)) + gazetteer {
            let key = ContentValidator.normalize(p.name) + "|" + ContentValidator.normalize(p.countryName)
            if seen.insert(key).inserted { result.append(p) }
        }
        return result
    }

    public func country(_ id: String) -> Country? { countries.first { $0.id == id } }
    public func destination(_ id: String) -> Destination? { destinations.first { $0.id == id } }
    public func destinations(in countryID: String) -> [Destination] {
        destinations.filter { $0.countryID == countryID }
    }
}
