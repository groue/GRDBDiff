import MapKit

// A map annotation that wraps a Place database record
final class PlaceAnnotation: NSObject, MKAnnotation {
    var place: Place {
        // Support MKMapView key-value observing on coordinates
        willSet { willChangeValue(forKey: "coordinate") }
        didSet { didChangeValue(forKey: "coordinate") }
    }
    
    @objc var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    init(_ place: Place) {
        self.place = place
    }
}

