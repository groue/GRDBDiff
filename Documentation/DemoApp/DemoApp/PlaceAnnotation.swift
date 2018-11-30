import GRDB
import MapKit

// A map annotation that wraps a Place database record
final class PlaceAnnotation: NSObject, MKAnnotation {
    var place: Place {
        // Support MKMapView key-value observing on coordinates
        willSet { willChangeValue(forKey: "coordinate") }
        didSet { didChangeValue(forKey: "coordinate") }
    }
    
    var nextPlace: Place?
    
    @objc var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    init(_ place: Place) {
        self.place = place
    }
}

// Turn PlaceAnnotation into a GRDB record, so that it can be observed
extension PlaceAnnotation: FetchableRecord, PersistableRecord {
    static let databaseTableName = Place.databaseTableName
    
    convenience init(row: Row) {
        self.init(Place(row: row))
    }
    
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}
