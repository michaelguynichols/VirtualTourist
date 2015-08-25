//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/10/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var collectionViewHelper: UICollectionView!
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    var pin: Pin?
    var cache = ImageCache.Caches.imageCache
    var downloadInProgress = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setting map delegate
        map.delegate = self
        
        // Zooming in map region to passed pin's location
        setMapRegion()
        
        // Creating the delegate and data source for the collection VC
        collectionViewHelper.delegate = self
        collectionViewHelper.dataSource = self
        
        view.addSubview(collectionViewHelper)
        
        // Don't want the map to move
        map.scrollEnabled = false
        
        // Setting fetchedResultsController delegate and performing fetch.
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        flickrAPICall()
        
    }
    
    // Convenient property to access core data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance().managedObjectContext!
    }
    
    // Helper function to save the context on changes
    func saveContext() {
        CoreDataStack.sharedInstance().saveContext()
    }
    
    // Returning the number of objects in the collection
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }
    
    // Configuring sell at each index
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            
            let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
            let CellIdentifier = "photoCell"
            
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! CustomPhotoAlbumCell
            
            cell.activity.hidesWhenStopped = true
            
            cell.activity.startAnimating()
            
            configureCell(cell, photo: photo)
            
            return cell
    }
    
    // Allow deletion only if download from Flickr completed
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if !downloadInProgress {
            let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
            deletePhoto(photo)
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        if !downloadInProgress {
            switch type {
            case .Insert:
                let photo = anObject as! Photo
            case .Delete:
                collectionViewHelper.deleteItemsAtIndexPaths([indexPath!])
            case .Update:
                let cell = collectionViewHelper.cellForItemAtIndexPath(indexPath!) as! CustomPhotoAlbumCell
                let photo = controller.objectAtIndexPath(indexPath!) as! Photo
                configureCell(cell, photo: photo)
            default:
                return
            }
        }
        
    }
    
    // Function to configure the cell depending on whether it is nil, already cached, or has a path but needs to be downloaded.
    func configureCell(cell: CustomPhotoAlbumCell, photo: Photo) {
        
        var fotoImage = UIImage(named: "placeholder")
        cell.collectionImageView!.image = nil
        
        if photo.imagePath == nil || photo.imagePath == "" {
            fotoImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            fotoImage = photo.photoImage
            cell.activity.stopAnimating()
        }
            
        else { // Photo has an image name, but it is not downloaded yet.
            
            var flickr = FlickrAPI(lat: pin!.latitude as! Double, lon: pin!.longitude as! Double)
            
            // Start the task that will eventually download the image
            let task = flickr.taskForImage(photo.imagePath!) { data, error in
                if let error = error {
                    dispatch_async(dispatch_get_main_queue()) {
                        fotoImage = UIImage(named: "noImage")
                    }
                }
                
                if let data = data {
                    
                    // Create the image
                    let image = UIImage(data: data)
                    
                    // Update the model, so that the infrmation gets cached
                    photo.photoImage = image
                    
                    // Update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.collectionImageView!.image = image
                        cell.activity.stopAnimating()
                    }
                }
            }
            
            // This is the custom property on this cell. See CustomPhotoAlbumCell for details.
            cell.taskToCancelifCellIsReused = task
        }
        cell.collectionImageView!.image = fotoImage
    }
    
    // The call to the Flickr photo search
    func flickrAPICall() {
        
        if let pin = pin {
            if pin.photos.isEmpty {
                
                // Toggle buttons during download
                self.toggleButtonsDuringDownload(false, navButtonStatus: true, downloadProgress: true)
                
                var flickr = FlickrAPI(lat: pin.latitude as! Double, lon: pin.longitude as! Double)
                flickr.search() {JSONResult, error in
                    if let error = error {
                        println("Download Error")
                    } else {
                        if let result = JSONResult as? [[String: AnyObject]] {
                            
                            // Parse the array of photo dictionaries in the photos array
                            var photos = result.map() { (dictionary: [String : AnyObject]) -> Photo in
                                let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                photo.pin = self.pin
                                return photo
                            }
                            
                            self.saveContext()
                            
                            dispatch_async(dispatch_get_main_queue()) {
                                self.collectionViewHelper.reloadData()
                                
                                // Adding a brief delay to ensure enough time for photos to download.
                                let delay = 1 * Double(NSEC_PER_SEC)
                                let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                                dispatch_after(time, dispatch_get_main_queue()) {
                                    self.toggleButtonsDuringDownload(true, navButtonStatus: false, downloadProgress: false)
                                }
                                
                            }
                            
                        }
                    }
                }
            }
        }
    }
    
    // NSFetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imagePath", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin!);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
        }()
    
    // Helper function to set map's region to the same as the pin's and zoom in
    func setMapRegion() {
        
        if let pin = pin {
            
            var location = CLLocationCoordinate2D(
                latitude: pin.coordinate.latitude,
                longitude: pin.coordinate.longitude
            )
            
            var span = MKCoordinateSpanMake(0.5, 0.5)
            var region = MKCoordinateRegion(center: location, span: span)
            
            map.addAnnotation(pin)
            
            map.setRegion(region, animated: true)
        }
        
    }
    
    // Explicitly delete a photo from the cache and context
    func deletePhoto(photo: Photo) {
        cache.deletePhotoCache(photo)
        sharedContext.deleteObject(photo)
        saveContext()
    }
    
    // Explicitly delete all photos
    func deleteAllPhotos(completionHandler: (result: Bool) -> Void) {
        for photo in pin!.photos {
            deletePhoto(photo)
        }
        
        if pin!.photos.isEmpty {
            completionHandler(result: true)
        } else {
            completionHandler(result: false)
        }
    }
    
    // Reload collection view if changes occur
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionViewHelper.reloadData()
        }
        
    }
    
    // Delete current photos and grab new Flickr photos
    @IBAction func reloadPhotos(sender: UIBarButtonItem) {
        
        // Toggle buttons during download
        self.toggleButtonsDuringDownload(false, navButtonStatus: true, downloadProgress: true)
        
        deleteAllPhotos() { result in
            if result {
                self.flickrAPICall()
            } else {
                println("error")
            }
        }
        
    }
    
    // Helper function to enable / disable buttons during download.
    func toggleButtonsDuringDownload(newCollectionStatus: Bool, navButtonStatus: Bool, downloadProgress: Bool) {
        downloadInProgress = downloadProgress
        newCollectionButton.enabled = newCollectionStatus
        navigationItem.setHidesBackButton(navButtonStatus, animated: true)
        
        toggleButtonTitle()
    }
    
    // Helper function to change title during download.
    func toggleButtonTitle() {
        if downloadInProgress {
            newCollectionButton.title = "Download in Progress"
        } else {
            newCollectionButton.title = "New Collection"
        }
    }
    
    // Helper function to make sure all photos are deleted from the cache - for debugging.
    func printFiles() {
        // Get the documents folder url
        let documentsUrl =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as! NSURL
        
        // Get the directory contents (including folders)
        if let directoryContents =  NSFileManager.defaultManager().contentsOfDirectoryAtPath(documentsUrl.path!, error: nil) {
            println(directoryContents)
        }
        
    }
    
}