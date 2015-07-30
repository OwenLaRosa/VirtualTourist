//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 6/30/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Pin)

/// Virtual Tourist Pin Managed Object
///
/// Stores map coordinate and references associated with a specific location. Used to generate pins to be displayed on a map view.
class Pin: NSManagedObject {
    
    @NSManaged var longitude: NSNumber
    @NSManaged var latitude: NSNumber
    @NSManaged var photos: [Photo]
    @NSManaged var nextPage: NSNumber
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(location: CLLocationCoordinate2D, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = location.latitude as Double
        longitude = location.longitude as Double
        nextPage = 1
    }
    
}
