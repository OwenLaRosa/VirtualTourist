//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 6/30/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import CoreData

@objc(Photo)

/// Virtual Tourist Photo Managed Object
/// Stores the file path for the corresponding image resource. Each instance of this class belongs to a Pin object which can be referenced from this class.
class Photo: NSManagedObject {
    
    @NSManaged var imagePath: String
    @NSManaged var location: Pin
    @NSManaged var pathInfo: PathInformation
    var isDownloading = false
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(imagePath: String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.imagePath = "\(imagePath).jpg"
    }
    
    override func prepareForDeletion() {
        // called whenever a photo object is removed, CoreData will also delete all photos when a pin object is removed
        NSFileManager.defaultManager().removeItemAtPath(Constants.documentsDirectory+imagePath, error: nil)
    }
    
}
