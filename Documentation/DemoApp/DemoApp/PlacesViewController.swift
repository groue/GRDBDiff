import UIKit
import MapKit
import GRDB
import GRDBDiff

class PlacesViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    private var favoritesButton: UIButton!
    private var displaysFavorites = false {
        didSet {
            setupTitle()
            setupMapView()
            favoritesButton.isSelected = displaysFavorites
        }
    }
    private var placesRequest: QueryInterfaceRequest<Place> {
        if displaysFavorites {
            return Place.favorites()
        } else {
            return Place.all()
        }
    }
    private var placeCountObserver: TransactionObserver?
    private var annotationsObserver: TransactionObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbarItems()
        setupFavoritesButton()
        setupTitle()
        setupMapView()
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
                    place.isFavorite = Bool.random()
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
    
    @IBAction func toggleFavorites() {
        displaysFavorites.toggle()
    }
}

// MARK: - View

extension PlacesViewController: UIToolbarDelegate {
    func setupFavoritesButton() {
        favoritesButton = UIButton(type: .system)
        favoritesButton.setTitle("Favorites", for: .normal)
        favoritesButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        favoritesButton.addTarget(self, action: #selector(toggleFavorites), for: .touchUpInside)
        
        let barButtomItem = UIBarButtonItem(customView: favoritesButton)
        navigationItem.rightBarButtonItem = barButtomItem
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
    
    func setupTitle() {
        // Track changes in the number of places
        placeCountObserver = try! ValueObservation
            .trackingCount(placesRequest)
            .start(in: dbPool) { [unowned self] count in
                switch count {
                case 0: self.navigationItem.title = "No Place"
                case 1: self.navigationItem.title = "1 Place"
                default: self.navigationItem.title = "\(count) Places"
                }
        }
    }
}

// MARK: - Database Observation

extension PlacesViewController: MKMapViewDelegate {
    private func setupMapView() {
        // Let's use the ValueObservation.setDifferencesFromRequest(...)
        // method provided by GRDBDiff in order to track the inserted, deleted,
        // and updated place annotations.
        //
        // This method requires a request ordered by primary key.
        let annotationsRequest = placesRequest
            .orderByPrimaryKey()
            .asRequest(of: PlaceAnnotation.self)
        
        // The map may already contain place annotations.
        //
        // ValueObservation.setDifferencesFromRequest(...) wants this initial
        // array to be ordered by primary key:
        let currentAnnotations = mapView.annotations
            .compactMap { $0 as? PlaceAnnotation }
            .sorted { $0.place.id! < $1.place.id! }
        
        // Removing and adding annotations in a map view is straightforward,
        // but updating annotations needs a special care:
        //
        // It is a good practice to reuse instances of annotations, for best
        // visual results, and preservation of the user's selection.
        // However, the modifications must happen on the main thread.
        annotationsObserver = try! ValueObservation
            .trackingAll(annotationsRequest)
            .setDifferencesFromRequest(startingFrom: currentAnnotations, onUpdate: { reusedAnnotation, newRow in
                // Not on the main thread here: remember the new place, but
                // wait for updateMapView(with:) below.
                reusedAnnotation.newPlace = Place(row: newRow)
                return reusedAnnotation
            })
            .start(in: dbPool) { [unowned self] diff in
                // On the main thread
                self.updateMapView(with: diff)
            }
    }
    
    private func updateMapView(with diff: SetDiff<PlaceAnnotation>) {
        mapView.removeAnnotations(diff.deleted)
        mapView.addAnnotations(diff.inserted)
        for annotation in diff.updated {
            // See setupMapView() for an explanation.
            annotation.place = annotation.newPlace!
            
            // Update eventual annotation view if present
            if let view = mapView.view(for: annotation) as? MKMarkerAnnotationView {
                configure(view, for: annotation)
            }
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
            let edgePadding = UIEdgeInsets(top: 80, left: 40, bottom: 40, right: 40)
            mapView.setVisibleMapRect(zoomRect, edgePadding: edgePadding, animated: animated)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? PlaceAnnotation else {
            return nil
        }
        let view: MKMarkerAnnotationView
        if let recycledView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotation") as? MKMarkerAnnotationView {
            view = recycledView
        } else {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
            view.annotation = annotation
        }
        view.displayPriority = .required
        configure(view, for: annotation)
        return view
    }
    
    private func configure(_ view: MKMarkerAnnotationView, for annotation: PlaceAnnotation) {
        view.markerTintColor = annotation.place.isFavorite ? .orange : view.tintColor
    }
}

/// A map annotation.
///
/// It adopts all the protocols we need in PlacesViewController.setupMapView().
///
/// - MKAnnotation so that it can feed the map view.
///
/// - FetchableRecord makes it possible to fetch annotations from the database.
///
/// - TableRecord and PersistableRecord make it possible to use the
///   `ValueObservation.setDifferencesFromRequest(startingFrom:onUpdate:)` method.
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
    /// See PlacesViewController.setupMapView().
    var newPlace: Place?
    
    /// Part of the FetchableRecord protocol
    init(row: Row) {
        self.place = Place(row: row)
    }
    
    /// Part of the PersistableRecord protocol
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}
