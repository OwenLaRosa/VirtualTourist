//
//  PathInformation.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 7/9/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import CoreData

@objc(PathInformation)

/// Virtual Touritst PathInformation Managed Object
/// Stores the information needed to build the URL for image resources on Flickr. This information is used to re-initiate downloads after they have been canceled.
class PathInformation: NSManagedObject {
    
    @NSManaged var farm: NSNumber
    @NSManaged var server: String
    @NSManaged var id: String
    @NSManaged var secret: String
    @NSManaged var photo: Photo
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("PathInformation", inManagedObjectContext: context)!
        
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        farm = dictionary["farm"]! as! Int
        server = dictionary["server"]! as! String
        id = dictionary["id"]! as! String
        secret = dictionary["secret"]! as! String
    }
    
    /// Returns the Flickr URL for the corresponding photo instance.
    func getPath() -> String {
        return "https://farm\(farm).static.flickr.com/\(server)/\(id)_\(secret).jpg"
    }
    
}
