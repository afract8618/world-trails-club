import Foundation

public enum ContentError: Error, Equatable, LocalizedError {
    case missingResource(String)
    case decodingFailed(String)
    case invalid([ContentIssue])

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Content file \(name) is missing from the app bundle."
        case .decodingFailed(let detail): return "Content could not be read: \(detail)"
        case .invalid(let issues): return "Content failed validation (\(issues.count) issue(s))."
        }
    }
}

public enum ContentLoader {
    /// Loads and validates the content pack bundled with the core package.
    public static func loadBundled() throws -> ContentPack {
        guard let url = Bundle.module.url(forResource: "destinations", withExtension: "json") else {
            throw ContentError.missingResource("destinations.json")
        }
        return try load(from: Data(contentsOf: url))
    }

    /// Decodes and validates. Validation errors are fatal so bad content never reaches players.
    public static func load(from data: Data) throws -> ContentPack {
        let pack: ContentPack
        do {
            pack = try JSONDecoder().decode(ContentPack.self, from: data)
        } catch {
            throw ContentError.decodingFailed(String(describing: error))
        }
        let issues = ContentValidator.validate(pack)
        guard issues.isEmpty else { throw ContentError.invalid(issues) }
        return pack
    }
}
