import UIKit
import MapKit
import GRDB
import GRDBDiff

class PlacesViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    private var annotationsObserver: TransactionObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
        
        // Start observing the database
        setupMapView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop observing the database
        annotationsObserver = nil
    }
}

// MARK: - Actions

extension PlacesViewController {
    
    private func setupToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlaces)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    @IBAction func deletePlaces() {
        try! dbPool.write { db in
            _ = try Place.deleteAll(db)
        }
    }
    
    @IBAction func refresh() {
        try! dbPool.write { db in
            if try Place.fetchCount(db) == 0 {
                // Insert places
                for _ in 0..<10 {
                    var place = Place.random()
                    try place.insert(db)
                }
            } else {
                // Insert a place
                if Bool.random() {
                    var place = Place.random()
                    try place.insert(db)
                }
                // Delete a random place
                if Bool.random() {
                    try Place.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some places
                for var place in try Place.fetchAll(db) where Bool.random() {
                    place.coordinate = CLLocationCoordinate2D.random(withinDistance: 300, from: place.coordinate)
                    try place.update(db)
                }
            }
        }
    }
    
    @IBAction func stressTest() {
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refresh()
            }
        }
    }
}

// MARK: - Map View

extension PlacesViewController: MKMapViewDelegate {
    
    private func setupMapView() {
        // We want to track the sets of inserted, deleted, and updated places,
        // so that we can update the mapView accordingly.
        //
        // We'll use the ValueObservation.setDifferences(...) method
        // provided by GRDBDiff.
        //
        // Its first parameter is a database request of observed records,
        // ordered by primary key. We have made our PlaceAnnotation a GRDB
        // record, so the request is easy to build:
        let annotationsRequest = PlaceAnnotation.orderByPrimaryKey()
        
        // The map may already contain place annotations. The differences have
        // to take them in account.
        //
        // ValueObservation.setDifferences(...) accepts an initialElements
        // parameter, which is an array ordered by primary key:
        let initialAnnotations = mapView.annotations
            .compactMap { $0 as? PlaceAnnotation }
            .sorted { $0.place.id! < $1.place.id! }
        
        // Now let's set up the database observation.
        //
        // Map view annotations need a special care: when annotations are
        // modified, it is not a good practice to remove the old version from
        // the map, and add the new version. It does not provide good visual
        // results. Instead, it is better to modify the annotation in place: the
        // MKMapView uses Key-Value Observation in order to update the
        // annotation view accordingly.
        //
        // Such modifications of annotations must happen on the
        // main thread.
        //
        // So let's ask the observation to reuse an annotation when it is
        // modified: this is the `updateElement` parameter. But don't update
        // the annotation right away: wait until we are back on the main queue
        // before we modify the annotation on the map (this will happen in
        // updateMapView(with:) below.
        let annotationObservation = ValueObservation.setDifferences(
            in: annotationsRequest,
            initialElements: initialAnnotations,
            updateElement: { annotation, row in
                // Not on the main queue here
                annotation.nextPlace = Place(row: row)
                return annotation
        })
        
        // Start the database observation.
        annotationsObserver = try! annotationObservation.start(in: dbPool) { [weak self] diff in
            self?.updateMapView(with: diff)
        }
    }
    
    private func updateMapView(with diff: SetDifferences<PlaceAnnotation>) {
        mapView.addAnnotations(diff.inserted)
        mapView.removeAnnotations(diff.deleted)
        for annotation in diff.updated {
            // Modify the annotation now, on the main thread.
            // See setupMapView() for a longer explanation.
            annotation.place = annotation.nextPlace!
        }
        
        zoomOnPlaces(animated: true)
    }
    
    private func zoomOnPlaces(animated: Bool) {
        // Turn all annotations into zero-sized map rects, that we will union
        // to build the zooming map rect.
        let rects = mapView.annotations.map { annotation in
            MKMapRect(
                origin: MKMapPoint(annotation.coordinate),
                size: MKMapSize(width: 0, height: 0))
        }
        
        // No rect => no annotation => no zoom
        guard let firstRect = rects.first else {
            return
        }
        
        // Union rects
        let zoomRect = rects.dropFirst().reduce(firstRect) { $0.union($1) }
        
        // Zoom
        mapView.setVisibleMapRect(
            zoomRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: animated)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: "annotation") {
            view.annotation = annotation
            view.displayPriority = .required
            return view
        }
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        view.displayPriority = .required
        return view
    }
    
    private func findPlaceAnnotation(id: Int64?) -> PlaceAnnotation? {
        for annotation in mapView.annotations {
            if let placeAnnotation = annotation as? PlaceAnnotation,
                placeAnnotation.place.id == id {
                return placeAnnotation
            }
        }
        return nil
    }
}

/// A map annotation that wraps a Place database record.
private final class PlaceAnnotation: NSObject, MKAnnotation {
    /// The Place record that provides the coordinate of the annotation.
    ///
    /// The MKAnnotation documentation says:
    ///
    /// https://developer.apple.com/documentation/mapkit/mkannotation/1429528-setcoordinate
    /// > [...] you must update the value of the coordinate in a key-value observing
    /// > (KVO) compliant way.
    var place: Place {
        // Support MKMapView key-value observing on coordinates
        willSet { willChangeValue(forKey: "coordinate") }
        didSet { didChangeValue(forKey: "coordinate") }
    }
    
    /// Used during database observation. See PlacesViewController.setupMapView().
    var nextPlace: Place?
    
    /// The annotation coordinate, KVO-compliant.
    @objc var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    init(_ place: Place) {
        self.place = place
    }
}

/// Turn PlaceAnnotation into a GRDB record, so that it can be observed in
/// PlacesViewController.setupMapView().
///
/// Just inherit record configuration from the wrapped Place type.
extension PlaceAnnotation: FetchableRecord, PersistableRecord {
    static let databaseTableName = Place.databaseTableName
    
    convenience init(row: Row) {
        self.init(Place(row: row))
    }
    
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}
