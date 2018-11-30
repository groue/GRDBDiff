import UIKit
import MapKit
import GRDB
import GRDBDiff

class PlacesViewController: UIViewController {
    private var annotationsObserver: TransactionObserver?
    
    @IBOutlet private var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupMapView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
        zoomOnPlaces(animated: false)
    }
}

extension PlacesViewController {
    
    // MARK: - Actions
    
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
                for _ in 0..<8 {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
            } else {
                // Insert a place
                if Bool.random() {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
                // Delete a random place
                if Bool.random() {
                    try Place.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some places
                for place in try Place.fetchAll(db) where Bool.random() {
                    var place = place
                    place.latitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
                    place.longitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
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

extension PlacesViewController: MKMapViewDelegate {
    
    // MARK: - Map View
    
    private func setupMapView() {
        let annotations = PlaceAnnotation.orderByPrimaryKey()
        
        let annotationObservation = ValueObservation.trackingSetDifferences(
            in: annotations,
            updateElement: { annotation, row in
                annotation.nextPlace = Place(row: row)
                return annotation
        })
        
        annotationsObserver = try! annotationObservation.start(in: dbPool) { [weak self] diff in
            self?.updateMapView(with: diff)
        }
    }
    
    private func updateMapView(with diff: SetDifferences<PlaceAnnotation>) {
        mapView.addAnnotations(diff.inserted)
        mapView.removeAnnotations(diff.deleted)
        for updatedAnnotation in diff.updated {
            updatedAnnotation.place = updatedAnnotation.nextPlace!
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
        let zoomRect = rects
            .suffix(from: 1)
            .reduce(firstRect) { $0.union($1) }
        
        // Zoom
        mapView.setVisibleMapRect(
            zoomRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: animated)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: "annotation") {
            return view
        }
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        view.displayPriority = .required // opt out of clustering in order to show *all* annotations
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
