//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/5/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionButton: UIButton!
    @IBOutlet weak var noImagesLabel: UILabel!
    
    var dataController: DataController!
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    var parentPin: MKAnnotation!
    
    var saveObserverToken: Any?
    var deleteMode = false
    var itemChanges: [[Any?]] = []
    var selectedCells: [Photo] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        noImagesLabel.isHidden = true
        
        configureCollectionView()
        configureNavigationBar()
        configureMap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setUpFetchedResultsController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        fetchedResultsController = nil
    }
    
    @objc func backToMap() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func collectionButtonPressed(_ sender: Any) {
        if deleteMode {
            deleteSelectedPictures()
        } else {
            getPhotosFromFlickr()
        }
    }
    
    fileprivate func deleteSelectedPictures() {
        for photo in selectedCells {
            dataController.viewContext.delete(photo)
            try? dataController.viewContext.save()
        }
        selectedCells.removeAll()
        deleteMode = false
        collectionButton.setTitle("Get New Images", for: .normal)
    }
    
    fileprivate func getPhotosFromFlickr() {
        collectionButton.isEnabled = false
        
        let backgroundContext: NSManagedObjectContext! = dataController.backgroundContext
        let coordinate = parentPin.coordinate
        
        let pinID = (parentPin as! Pin).objectID
        
        (parentPin as! Pin).photos = NSSet() // Does this erase the previously saved images for the pin?
        
        backgroundContext.perform {
            Client.sharedInstance().searchPhotosByLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) { (success, error, photos) in
                
                if success {
                    
                    let backgroundPin = backgroundContext.object(with: pinID) as! Pin
                    
                    for urlString in photos! {

                        let newPhoto = Photo(context: backgroundContext)
                        newPhoto.pin = backgroundPin
                        newPhoto.downloadDate = Date()
                        newPhoto.urlString = urlString

                        try? backgroundContext.save()
                    }
                        
                        DispatchQueue.main.async {
                            if photos!.count == 0 {
                                self.noImagesLabel.isHidden = false
                            }
                            self.collectionButton.isEnabled = true
                        }
                    
                } else {
                    debugPrint(error!)
                }
            }
        }
    }
}

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[0].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoCell
        let photo = fetchedResultsController.object(at: indexPath)
        photoCell.activityIndicator.isHidden = false
        
        photoCell.activityIndicator.startAnimating()
        downloadImage(imagePath: photo.urlString!) { (data, errorString) in
            
            if let error = errorString {
                debugPrint(error)
                self.noImagesLabel.text = "There was an error downloading the images\n\(error)"
            }
            else {
                DispatchQueue.main.async {
                    photoCell.imageView.image = UIImage(data: data!)!
                    photoCell.activityIndicator.isHidden = true
                    photoCell.activityIndicator.stopAnimating()
                }
            }
        }
        return photoCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
        let cell = collectionView.cellForItem(at: indexPath)
        let selectedPhoto = fetchedResultsController.object(at: indexPath)
        
        if !(selectedCells.contains(selectedPhoto)) {
            cell?.alpha = 0.5
            selectedCells.append(selectedPhoto)
        }
        
        deleteMode = true
        collectionButton.setTitle("Delete Photos", for: .normal)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        let selectedPhoto = fetchedResultsController.object(at: indexPath)
        
        cell?.alpha = 1
        selectedCells.remove(at: selectedCells.index(of: selectedPhoto)!)
        
        if selectedCells.count == 0 {
            deleteMode = false
            collectionButton.setTitle("Get New images", for: .normal)
        }
    }
    
    func downloadImage( imagePath:String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void){
        let session = URLSession.shared
        let imgURL = NSURL(string: imagePath)
        let request: NSURLRequest = NSURLRequest(url: imgURL! as URL)
        
        let task = session.dataTask(with: request as URLRequest) {data, response, downloadError in
            
            if downloadError != nil {
                completionHandler(nil, "Could not download image \(imagePath)")
            } else {
                
                completionHandler(data, nil)
            }
        }
        
        task.resume()
    }
    
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        
        let itemChange: [Any?] = [type, indexPath, newIndexPath]
        
        itemChanges.append(itemChange)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        collectionView?.performBatchUpdates({
            
            for change in self.itemChanges {
                switch change[0] as! NSFetchedResultsChangeType {
                case .insert: self.collectionView?.insertItems(at: [change[2] as! IndexPath])
                case .delete: self.collectionView?.deleteItems(at: [change[1] as! IndexPath])
                default: debugPrint("... how?")
                }
            }
            self.itemChanges.removeAll()
            
        })
    }
}

extension PhotoAlbumViewController {
    
    fileprivate func configureMap() {
        mapView.region = MKCoordinateRegion(center: parentPin.coordinate, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
        mapView.addAnnotation(parentPin)
    }
    
    fileprivate func configureNavigationBar() {
        navBar.delegate = self
        let navItem = UINavigationItem(title: "Photos")
        navItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(backToMap))
        navBar.setItems([navItem], animated: false)
    }
    
    fileprivate func configureCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true
    }
    
    fileprivate func setUpFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", parentPin as! Pin)
        fetchRequest.predicate = predicate
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "downloadDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let parentPinCoordString = String(parentPin.coordinate.latitude) + "|" + String(parentPin.coordinate.longitude)
        //debugPrint(parentPinCoordString)
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(parentPinCoordString)/photos" )
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        
        if fetchedResultsController.fetchedObjects?.count == 0 {
            getPhotosFromFlickr()
        }
    }
}

extension PhotoAlbumViewController: UINavigationBarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
}


