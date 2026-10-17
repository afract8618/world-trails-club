import Foundation

public struct GeoPoint: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum CompassDirection: String, CaseIterable, Codable, Sendable {
    case n = "N", ne = "NE", e = "E", se = "SE", s = "S", sw = "SW", w = "W", nw = "NW"

    /// Rotation in degrees for an arrow glyph pointing north at 0°.
    public var degrees: Double {
        Double(CompassDirection.allCases.firstIndex(of: self)!) * 45
    }

    public init(bearing: Double) {
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45) % 8
        self = CompassDirection.allCases[index]
    }
}

public enum Geo {
    public static let earthRadiusKm = 6371.0

    /// Great-circle distance (haversine), in kilometres.
    public static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(h)))
    }

    /// Initial bearing from `a` to `b`, in degrees clockwise from true north (0..<360).
    public static func bearing(from a: GeoPoint, to b: GeoPoint) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 0...100 "how close" score for the proximity meter. Half of Earth's circumference ≈ 20,015 km.
    public static func proximityPercent(distanceKm: Double) -> Int {
        let maxDistance = 20_015.0
        return max(0, min(100, Int((1 - distanceKm / maxDistance) * 100)))
    }
}
