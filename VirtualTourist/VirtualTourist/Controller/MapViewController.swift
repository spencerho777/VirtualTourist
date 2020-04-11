//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/5/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import UIKit
import CoreData
import MapKit

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var editPinsButton: UIBarButtonItem!
    
    var dataController: DataController!
    
    var fetchedResultsController: NSFetchedResultsController<Pin>!
    
    let MapRegion = "mapRegion"
    var isDeletingPins = false
    
    var currentPin: Pin!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureMap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setUpFetchedResultsController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        fetchedResultsController = nil
    }
    
    fileprivate func configureMap() {
        let startRegionDict = UserDefaults.standard.value(forKey: MapRegion) as! [String: Double]
        let defaultRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: startRegionDict["latitude"]!, longitude: startRegionDict["longitude"]!), span: MKCoordinateSpan(latitudeDelta: startRegionDict["latitudeDelta"]!, longitudeDelta: startRegionDict["longitudeDelta"]!))
        mapView.region = defaultRegion
        //debugPrint(mapView.region)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(addPin(gestureRecognizer:)))
        mapView.addGestureRecognizer(gestureRecognizer)
    }
    
    fileprivate func setUpFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "pins" )
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    @objc func addPin(gestureRecognizer: UIGestureRecognizer) {
        let coordinates = getCoordinatesFromTouchPoint(gestureRecognizer)
        if gestureRecognizer.state == UIGestureRecognizer.State.began {
            print("begin")
            let pin = Pin(context: dataController.viewContext)
            pin.creationDate = Date()
            pin.latitude = coordinates.latitude
            pin.longitude = coordinates.longitude
            currentPin = pin
        }
        else if gestureRecognizer.state == UIGestureRecognizer.State.changed {
            print("changed")
            currentPin.latitude = coordinates.latitude
            currentPin.longitude = coordinates.longitude
        }
        else if gestureRecognizer.state == UIGestureRecognizer.State.ended {
            print("ended")
            try? dataController.viewContext.save()
        }
    }
    
    func getCoordinatesFromTouchPoint(_ gestureRecognizer: UIGestureRecognizer) -> CLLocationCoordinate2D {
        let touchPoint = gestureRecognizer.location(in: mapView)
        return mapView.convert(touchPoint, toCoordinateFrom: mapView)
    }
    
    @IBAction func removePins(_ sender: Any) {
        isDeletingPins = !isDeletingPins
        editPinsButton.title = isDeletingPins ? "Done" : "Edit"
        self.title = isDeletingPins ? "Tap Pins to Delete" : "Virtual Tourist"
    }
    
}

extension MapViewController: MKMapViewDelegate {
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        let newRegion: [String: Double] = ["latitude": mapView.region.center.latitude, "longitude": mapView.region.center.longitude,
                                           "latitudeDelta": mapView.region.span.latitudeDelta, "longitudeDelta": mapView.region.span.longitudeDelta]
        UserDefaults.standard.set(newRegion, forKey: MapRegion)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if isDeletingPins {
            let pinToDelete = view.annotation as! Pin
            dataController.viewContext.delete(pinToDelete)
            try? dataController.viewContext.save()
            
        } else {
            let photoAlbumVC = storyboard?.instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
            photoAlbumVC.dataController = self.dataController
            photoAlbumVC.parentPin = view.annotation
            
            present(photoAlbumVC, animated: true, completion: nil)
        }
    }

    func mapViewWillStartRenderingMap(_ mapView: MKMapView) {
        let numberOfAnnotations = fetchedResultsController.sections?[0].numberOfObjects ?? 0
        
        for index in 0..<numberOfAnnotations {
            mapView.addAnnotation(fetchedResultsController.object(at: IndexPath(row: index, section: 0)))
        }
    }
}

extension MapViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        guard let pin = anObject as? Pin else {
            debugPrint("Why is something other than a pin affecting this controller?")
            return
        }
        
        switch type {
        case .insert:
            mapView.addAnnotation(pin)
        case .delete:
            mapView.removeAnnotation(pin)
        case .update:
            mapView.removeAnnotation(pin)
            mapView.addAnnotation(pin)
        default:
            break
        }
        
    }
}
