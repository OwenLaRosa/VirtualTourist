//
//  HelperMethods.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 7/22/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import MapKit

struct Helpers {
    
    var context: NSManagedObjectContext {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return delegate.managedObjectContext!
    }
    
    /// Performs a search and gets image links for the Pin so that they can be downloaded later.
    func getImages(pin: Pin, completionHandler: (error: String?) -> Void) {
        FlickrClient.sharedInstance().searchPhotosByLocation(CLLocationCoordinate2DMake(pin.latitude as Double, pin.longitude as Double), page: pin.nextPage as Int) {data, error in
            if error != nil {
                completionHandler(error: "0") // error code for failed download
            } else {
                // increment next page property to fetch a new set of images later
                if data!.count == 0 {
                    // reset image set to the first page for future downloads
                    pin.nextPage = NSNumber(integer: 1)
                    completionHandler(error: "1") // error code for no images on page
                } else {
                    let nextPage = (pin.nextPage as Int) + 1
                    pin.nextPage = NSNumber(integer: nextPage)
                }
                for i in data! {
                    // get the information necessary to build the file path
                    let pathInfoDictionary: [String: AnyObject] = [
                        "farm" : i["farm"]!,
                        "server" : i["server"]!,
                        "id" : i["id"]!,
                        "secret" : i["secret"]!
                    ]
                    // update core data on main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        let pathInfo = PathInformation(dictionary: pathInfoDictionary, context: self.context)
                        // create the photo object
                        let photo = Photo(imagePath: pathInfo.id, context: self.context)
                        
                        photo.location = pin
                        photo.pathInfo = pathInfo
                    }
                    completionHandler(error: nil)
                }
            }
        }
    }
    
    /// Determines whether or not all the images for the specified pin have been downloaded.
    func allImagesDownloaded(forPin pin: Pin) -> Bool {
        var result = true
        for i in pin.photos {
            // check if each of the file paths exist
            let filePath = Constants.documentsDirectory+i.imagePath
            if NSFileManager.defaultManager().fileExistsAtPath(filePath) == false {
                result = false
                break
            } // if the file exists, result will remain as true and the loop will continue
        }
        return result
    }
    
    /// Returns "s" if the number is not equal to one. Otherwise, an empty string is returned.
    func isPlural(number: Int) -> String {
        if number == 1 {
            return ""
        } else {
            return "s"
        }
    }
    
}
