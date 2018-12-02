import UIKit
import MapKit
import GRDB
import GRDBDiff

class PlacesViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    @IBOutlet private var topToolbar: UIToolbar!
    private var databaseObservationSwitch: UISwitch!
    private var isObservingDatabase = true {
        didSet { setupDatabaseObservation() }
    }
    private var placeCountObserver: TransactionObserver?
    private var annotationsObserver: TransactionObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbarItems()
        setupDatabaseObservationSwitch()
        setupDatabaseObservation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    
    func setupDatabaseObservation() {
        if isObservingDatabase {
            placeCountObserver = startPlaceCountObservation()
            annotationsObserver = startAnnotationsObservation()
        } else {
            placeCountObserver = nil
            annotationsObserver = nil
        }
    }
}

// MARK: - Actions

extension PlacesViewController {
    
    @IBAction func deletePlaces() {
        try! dbPool.write { db in
            _ = try Place.deleteAll(db)
        }
    }
    
    @IBAction func refresh() {
        try! dbPool.write { db in
            if try Place.fetchCount(db) == 0 {
                // Insert places
                for _ in 0..<5 {
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
    
    @IBAction func toggleDatabaseObservation() {
        isObservingDatabase.toggle()
    }
}

// MARK: - View

extension PlacesViewController: UIToolbarDelegate {
    func setupDatabaseObservationSwitch() {
        databaseObservationSwitch = UISwitch(frame: .zero)
        databaseObservationSwitch.sizeToFit()
        databaseObservationSwitch.isOn = isObservingDatabase
        databaseObservationSwitch.addTarget(self, action: #selector(toggleDatabaseObservation), for: .valueChanged)
        
        let label = UILabel(frame: .zero)
        label.text = "Observe Database"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.sizeToFit()
        
        topToolbar.items = [
            UIBarButtonItem(customView: label),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(customView: databaseObservationSwitch),
        ]
    }
    
    private func setupToolbarItems() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlaces)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
}

// MARK: - Database Observation

extension PlacesViewController: MKMapViewDelegate {
    func startPlaceCountObservation() -> TransactionObserver {
        // Track changes in the number of places
        return try! ValueObservation
            .trackingCount(Place.all())
            .start(in: dbPool) { [unowned self] count in
                switch count {
                case 0: self.navigationItem.title = "No Place"
                case 1: self.navigationItem.title = "1 Place"
                default: self.navigationItem.title = "\(count) Places"
                }
        }
    }
    
    private func startAnnotationsObservation() -> TransactionObserver {
        // We want to track the sets of inserted, deleted, and updated places,
        // so that we can update the mapView accordingly.
        //
        // We'll use the ValueObservation.setDifferencesFromRequest(...) method
        // provided by GRDBDiff.
        //
        // It can compute diffs from arrays of records ordered by primary key.
        // So let's observe database annotations, correctly ordered:
        let annotationsRequest = PlaceAnnotation.orderByPrimaryKey()
        let annotationsObservation = ValueObservation.trackingAll(annotationsRequest)
        
        // Now let's care of inserted, deleted, and updated annotations.
        //
        // The map may already contain place annotations. The differences have
        // to take them in account.
        //
        // ValueObservation.setDifferencesFromRequest(...) accepts an
        // initialElements parameter, which is an array ordered by primary key:
        let initialAnnotations = mapView.annotations
            .compactMap { $0 as? PlaceAnnotation }
            .sorted { $0.place.id! < $1.place.id! }
        
        // Removing and adding annotations in a map view is straightforward.
        // But updating annotations needs a special care:
        //
        // It is not a good practice to replace the annotation by removing an
        // old version and adding the new one: it does not provide good
        // visual results.
        //
        // Instead, it is better to reuse and modify the updated annotation.
        // The MKMapView uses Key-Value Observation in order to update the
        // annotation view accordingly. Such modifications of annotations must
        // happen on the main thread.
        //
        // So let's reuse annotations, and wait until we are back on the main
        // queue before we modify the annotation on the map (this will happen
        // in the updateMapView(with:) method below.
        let diffObservation = annotationsObservation.setDifferencesFromRequest(
            initialElements: initialAnnotations,
            updateElement: { reusedAnnotation, newRow in
                // Not on the main queue here
                reusedAnnotation.nextPlace = Place(row: newRow)
                return reusedAnnotation
        })
        
        // Start the database observation.
        return try! diffObservation.start(in: dbPool) { [unowned self] diff in
            self.updateMapView(with: diff)
        }
    }
    
    private func updateMapView(with diff: SetDiff<PlaceAnnotation>) {
        mapView.addAnnotations(diff.inserted)
        mapView.removeAnnotations(diff.deleted)
        for annotation in diff.updated {
            // On the main thread: we can update the annotation.
            // See startAnnotationsObservation() for a longer explanation.
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
        if zoomRect.size.width == 0 && zoomRect.size.height == 0 {
            mapView.setCenter(zoomRect.origin.coordinate, animated: animated)
        } else {
            let topToolbarHeight = topToolbar.frame.height
            let edgePadding = UIEdgeInsets(
                top: 80 + topToolbarHeight,
                left: 40,
                bottom: 40,
                right: 40)
            mapView.setVisibleMapRect(zoomRect, edgePadding: edgePadding, animated: animated)
        }
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
}

/// A map annotation.
///
/// It adopts all the proocols we need in PlacesViewController.startAnnotationsObservation().
///
/// - MKAnnotation so that it can feed the map view.
/// - FetchableRecord makes it possible to fetch annotations from the database.
/// - TableRecord makes it possible to define the
///   `PlaceAnnotation.orderByPrimaryKey()` observed request.
/// - TableRecord also makes it possible to use the
///   `ValueObservation.setDifferencesFromRequest(...)` method.
/// - PersistableRecord makes it possible to provide initial elements to the
///   `ValueObservation.setDifferencesFromRequest(...)` method.
private final class PlaceAnnotation:
    NSObject, MKAnnotation, FetchableRecord, TableRecord, PersistableRecord
{
    /// Part of the TableRecord protocol
    static let databaseTableName = Place.databaseTableName
    
    /// The place
    var place: Place {
        willSet { willChangeValue(for: \.coordinate) }
        didSet { didChangeValue(for: \.coordinate) }
    }

    /// The annotation coordinate, KVO-compliant.
    @objc var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    /// Used during database observation.
    /// See PlacesViewController.startAnnotationsObservation().
    var nextPlace: Place?

    /// Part of the FetchableRecord protocol
    init(row: Row) {
        self.place = Place(row: row)
    }
    
    /// Part of the PersistableRecord protocol
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}
