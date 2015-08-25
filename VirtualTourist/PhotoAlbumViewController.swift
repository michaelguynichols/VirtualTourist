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
        
        map.delegate = self
        
        setMapRegion()
        
        collectionViewHelper.delegate = self
        collectionViewHelper.dataSource = self
        
        view.addSubview(collectionViewHelper)
        
        map.scrollEnabled = false
        
        /*// We need just to get the documents folder url
        let documentsUrl =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as! NSURL
        
        // now lets get the directory contents (including folders)
        if let directoryContents =  NSFileManager.defaultManager().contentsOfDirectoryAtPath(documentsUrl.path!, error: nil) {
            println(directoryContents)
        }
        // if you want to filter the directory contents you can do like this:
        if let directoryUrls =  NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants, error: nil) {
            println(directoryUrls)
        }*/
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if pin!.photos.isEmpty {
            self.toggleButtonsDuringDownload(false, navButtonStatus: true, downloadProgress: true)
            flickrAPICall()
        }

    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance().managedObjectContext!
    }
    
    func saveContext() {
        CoreDataStack.sharedInstance().saveContext()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pin!.photos.count
    }
    
    func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let photo = pin!.photos[indexPath.row]
        let CellIdentifier = "photoCell"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! CustomPhotoAlbumCell
        
        cell.activity.hidesWhenStopped = true
        
        configureCell(cell, photo: photo)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
    {
        if !downloadInProgress {
            let photo = pin!.photos[indexPath.row]
        
            deletePhoto(photo)
        
            saveContext()
        
            collectionViewHelper.reloadData()
        }
        
    }
    
    func configureCell(cell: CustomPhotoAlbumCell, photo: Photo) {
        
        var fotoImage = UIImage(named: "placeholder")
        
        cell.collectionImageView!.image = nil
        cell.activity.startAnimating()
        
        if photo.imagePath == nil || photo.imagePath == "" {
            fotoImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            fotoImage = photo.photoImage
            cell.activity.stopAnimating()
        }
            
        else { // This is the interesting case. The movie has an image name, but it is not downloaded yet.
            
            var flickr = FlickrAPI(lat: pin!.latitude as! Double, lon: pin!.longitude as! Double)
            
            // Start the task that will eventually download the image
            let task = flickr.taskForImage(photo.imagePath!) { data, error in
                if let error = error {
                    println("Photo download error: \(error.localizedDescription)")
                }
                
                if let data = data {
                    
                    // Create the image
                    let image = UIImage(data: data)
                    
                    // update the model, so that the infrmation gets cashed
                    photo.photoImage = image
                    
                    // update the cell later, on the main thread
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
    
    func flickrAPICall() {

        if let pin = pin {
            if pin.photos.isEmpty {
                var flickr = FlickrAPI(lat: pin.latitude as! Double, lon: pin.longitude as! Double)
                flickr.search() {JSONResult, error in
                    if let error = error {
                        println("Download Error")
                    } else {
                        if let result = JSONResult as? [[String: AnyObject]] {
                            
                            // Parse the array of movies dictionaries
                            var photos = result.map() { (dictionary: [String : AnyObject]) -> Photo in
                                let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                
                                photo.pin = self.pin
                                
                                return photo
                            }
                            
                            // Update the table on the main thread
                            dispatch_async(dispatch_get_main_queue()) {
                                self.collectionViewHelper.reloadData()
                                self.toggleButtonsDuringDownload(true, navButtonStatus: false, downloadProgress: false)
                            }
                            
                            self.saveContext()
                            
                        }
                    }
                }

            }
        }
    }
    
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
    
    func deletePhoto(photo: Photo) {
        sharedContext.deleteObject(photo)
        cache.deleteImage(photo.fileName)
    }
    
    func deleteAllPhotos() {
        for photo in pin!.photos {
            deletePhoto(photo)
            println(pin!.photos.count)
        }
        println(pin!.photos.count)
        saveContext()
    }
    
    @IBAction func reloadPhotos(sender: UIBarButtonItem) {
        deleteAllPhotos()
        if pin!.photos.isEmpty {
            self.toggleButtonsDuringDownload(false, navButtonStatus: true, downloadProgress: true)
            flickrAPICall()
        }
    }
    
    func toggleButtonsDuringDownload(newCollectionStatus: Bool, navButtonStatus: Bool, downloadProgress: Bool) {
        newCollectionButton.enabled = newCollectionStatus
        navigationItem.setHidesBackButton(navButtonStatus, animated: true)
        downloadInProgress = downloadProgress
    }
    
}