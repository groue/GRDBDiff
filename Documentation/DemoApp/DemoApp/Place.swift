import CoreLocation
import MapKit
import GRDB

// A place
struct Place: Codable {
    var id: Int64?
    var isFavorite: Bool
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    /// Customize coding keys so that they can be used as GRDB columns
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, latitude, longitude, isFavorite
    }

    init(id: Int64?, coordinate: CLLocationCoordinate2D, isFavorite: Bool) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.isFavorite = isFavorite
    }
}

/// Adopt RowConvertible so that we can fetch places from the database.
/// Implementation is fully derived from Codable adoption.
extension Place: FetchableRecord { }

/// Adopt MutablePersistable so that we can create/update/delete places
/// in the database. Implementation is partially derived from Codable adoption.
extension Place: MutablePersistableRecord {
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension Place {
    /// A request that fetches favorite places
    static func favorites() -> QueryInterfaceRequest<Place> {
        return Place.filter(CodingKeys.isFavorite)
    }
}

extension Place {
    /// Returns a random place
    static func random() -> Place {
        let paris = CLLocationCoordinate2D(latitude: 48.85341, longitude: 2.3488)
        let coordinate = CLLocationCoordinate2D.random(withinDistance: 8000, from: paris)
        return Place(id: nil, coordinate: coordinate, isFavorite: Bool.random())
    }
}

extension CLLocationCoordinate2D {
    /// Returns a random coordinate
    static func random(withinDistance distance: CLLocationDistance, from center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // Generate a random point within a circle (uniformly)
        // https://stackoverflow.com/a/50746409/525656
        let radius = sqrt(Double.random(in: 0...1)) * distance
        let angle = Double.random(in: 0...1) * 2 * .pi
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: y, longitudinalMeters: x)
        return CLLocationCoordinate2D(
            latitude: center.latitude + copysign(region.span.latitudeDelta, y),
            longitude: center.longitude + copysign(region.span.longitudeDelta, x))
    }
}
