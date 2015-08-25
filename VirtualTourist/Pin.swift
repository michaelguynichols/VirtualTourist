//
//  Pin.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/10/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Pin)

class Pin: NSManagedObject, MKAnnotation {
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(lat: Double, lon: Double, context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = NSNumber(double: lat)
        longitude = NSNumber(double: lon)
        
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude as Double, longitude: longitude as Double)
    }
    
    
}