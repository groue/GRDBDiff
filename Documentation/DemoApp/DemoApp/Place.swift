import CoreLocation
import MapKit
import GRDB

// A place
struct Place: Codable {
    var id: Int64?
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    init(id: Int64?, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

// Adopt RowConvertible so that we can fetch places from the database.
// Implementation is automatically derived from Codable.
extension Place: FetchableRecord { }

// Adopt MutablePersistable so that we can create/update/delete places in the database.
// Implementation is partially derived from Codable.
extension Place: MutablePersistableRecord {
    static let databaseTableName = "place"
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// Place randomization
extension Place {
    static func random() -> Place {
        let paris = CLLocationCoordinate2D(latitude: 48.85341, longitude: 2.3488)
        let coordinate = CLLocationCoordinate2D.random(withinDistance: 8000, from: paris)
        return Place(id: nil, coordinate: coordinate)
    }
}

extension CLLocationCoordinate2D {
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
