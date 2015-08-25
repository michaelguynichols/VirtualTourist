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
        
        // Gesture recognizer
        let longTapAndHoldGesture = UILongPressGestureRecognizer(target: self, action: "dropPin:")
        
        map.addGestureRecognizer(longTapAndHoldGesture)
        
        // Load all saved pins
        map.addAnnotations(fetchAllPins())
        
        restoreMapRegion(true)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController!.navigationBarHidden = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationItem.title = "OK"
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance().managedObjectContext!
    }
    
    func saveContext() {
        CoreDataStack.sharedInstance().saveContext()
    }
    
    func dropPin(gesture: UIGestureRecognizer) {
        
        if gesture.state == .Began {
        
            var point = gesture.locationInView(map)
            var locCoord = map.convertPoint(point, toCoordinateFromView: map)
            
            let pin = Pin(lat: locCoord.latitude, lon: locCoord.longitude, context: sharedContext)
            
            map.addAnnotation(pin)
            
            saveContext()
            
        }
        
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        //cast pin
        let pin = view.annotation as! Pin
        
        map.deselectAnnotation(pin, animated: false)
        
        toPhotoAlbum(pin)
        
    }
    
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
    
    func toPhotoAlbum(pin: Pin) {
        
        var controller: PhotoAlbumViewController
        controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
        
        // Getting the current pin
        controller.pin = pin
        self.navigationController!.pushViewController(controller, animated: true)
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




