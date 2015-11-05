//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 7/1/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import MapKit
import UIKit

class FlickrClient: NSObject {
    
    /// Performs a GET request with the default and specified settings
    func taskForFlickrGetRequest(methodArguments: [String : AnyObject], completionHandler: (data: NSDictionary?, errorString: String?) -> Void) {
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: Constants.Flickr.BASE_URL + escapedParameters(methodArguments))!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, error in
            if error != nil {
                completionHandler(data: nil, errorString: error!.localizedDescription)
            } else {
                var parsingError: NSError? = nil
                let parsedResult = (try! NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)) as! NSDictionary
                completionHandler(data: parsedResult, errorString: nil)
            }
        }
        task.resume()
    }
    
    /// Returns search results for photos at a specified location
    func searchPhotosByLocation(location: CLLocationCoordinate2D, page: Int, completionHandler: (data: [[String : AnyObject]]?, errorString: String?) -> Void) {
        var methodArguments = Constants.Flickr.BASE_PARAMETERS
        methodArguments["method"] = Constants.Flickr.SEARCH_PHOTOS
        // geographic coordinates for radial search
        methodArguments["lat"] = "\(location.latitude)"
        methodArguments["lon"] = "\(location.longitude)"
        methodArguments["per_page"] = "21"
        methodArguments["page"] = "\(page)"
        taskForFlickrGetRequest(methodArguments) {data, error in
            if error != nil {
                completionHandler(data: nil, errorString: error)
            } else {
                if let photos = data?.valueForKey("photos") as? [String : AnyObject] {
                    let photoArray = photos["photo"] as? [[String : AnyObject]]
                    completionHandler(data: photoArray, errorString: nil)
                }
            }
        }
    }
    
    /// Downloads the binary data for the image at the given URL
    func downloadPhotoAtUrl(url: String, completionHandler: (data: NSData?, errorString: String?) -> Void) -> NSURLSessionTask {
        let sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfiguration)
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "GET"
        let task = session.dataTaskWithRequest(request) {data, response, error in
            if error != nil {
                completionHandler(data: nil, errorString: error!.localizedDescription)
            } else {
                completionHandler(data: data, errorString: nil)
            }
        }
        task.resume()
        
        return task
    }
    
    /// Formats method parameters into a string for Flickr request.
    /// As seen in Jarrod Parkes' FlickFinder sample app.
    private func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    class func sharedInstance() -> FlickrClient {
        
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        
        return Singleton.sharedInstance
    }

}
