//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/10/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var map: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Declare map delegate
        map.delegate = self
        
        // Gesture recognizer and assign dropPin method to it
        let longTapAndHoldGesture = UILongPressGestureRecognizer(target: self, action: "dropPin:")
        
        map.addGestureRecognizer(longTapAndHoldGesture)
        
        // Load all saved pins
        map.addAnnotations(fetchAllPins())
        
        // Reload the map's saved location.
        restoreMapRegion(true)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // Hiding the navbar
        navigationController!.navigationBarHidden = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        // Changing navbar title for the PhotoAlbumVC
        self.navigationItem.title = "OK"
    }
    
    // Helper property to access CoreDataStack
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance().managedObjectContext!
    }
    
    // Helper function to save the context after key changes
    func saveContext() {
        CoreDataStack.sharedInstance().saveContext()
    }
    
    // A function to drop a pin on the map if a long tap and hold
    func dropPin(gesture: UIGestureRecognizer) {
        
        if gesture.state == .Began {
            
            // Grabbing coords
            var point = gesture.locationInView(map)
            var locCoord = map.convertPoint(point, toCoordinateFromView: map)
            
            // Setting the annation as a pin
            let pin = Pin(lat: locCoord.latitude, lon: locCoord.longitude, context: sharedContext)
            
            map.addAnnotation(pin)
            
            saveContext()
            
        }
        
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        
        // Selecting the pin to pass to the PhotoAlbumVC
        let pin = view.annotation as! Pin
        
        map.deselectAnnotation(pin, animated: false)
        
        toPhotoAlbum(pin)
        
    }
    
    // Fetching all the pins
    func fetchAllPins() -> [Pin] {
        let error: NSErrorPointer = nil
        
        // Create the Fetch Request
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        // Execute the Fetch Request
        let results = sharedContext.executeFetchRequest(fetchRequest, error: error)
        
        // Check for Errors
        if error != nil {
            println("Error in fectchAllEvents(): \(error)")
        }
        
        // Return the results, cast to an array of Person objects
        return results as! [Pin]
    }
    
    // Helper function to push the view to the PhotoAlbumVC
    func toPhotoAlbum(pin: Pin) {
        
        var controller: PhotoAlbumViewController
        controller = storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
        
        // Getting the current pin to pass on
        controller.pin = pin
        navigationController!.pushViewController(controller, animated: true)
    }
    
    // Here we use the same filePath strategy as the Persistent Master Detail
    // A convenient property
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    func saveMapRegion() {
        
        // Place the "center" and "span" of the map into a dictionary
        // The "span" is the width and height of the map in degrees.
        // It represents the zoom level of the map.
        
        let dictionary = [
            "latitude" : map.region.center.latitude,
            "longitude" : map.region.center.longitude,
            "latitudeDelta" : map.region.span.latitudeDelta,
            "longitudeDelta" : map.region.span.longitudeDelta
        ]
        
        // Archive the dictionary into the filePath
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        // if we can unarchive a dictionary, we will use it to set the map back to its
        // previous center and span
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2DMake(latitude, longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta)
            
            let savedRegion = MKCoordinateRegionMake(center, span)
            
            map.setRegion(savedRegion, animated: animated)
            
            map.setCenterCoordinate(center, animated: true)
        }
    }
}

/**
*  This extension comforms to the MKMapViewDelegate protocol. This allows
*  the view controller to be notified whenever the map region changes. So
*  that it can save the new region.
*/

extension MapViewController : MKMapViewDelegate {
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
        navigationController!.navigationBarHidden = true
    }
}




