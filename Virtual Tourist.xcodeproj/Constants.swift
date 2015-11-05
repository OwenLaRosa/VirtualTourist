//
//  Constants.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 7/21/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation

struct Constants {
    
    /// Constants associated with the Flickr API
    struct Flickr {
        static let API_KEY = "751eec8def22fb19810bc86348b765d9"
        static let BASE_URL = "https://api.flickr.com/services/rest/"
        static let SEARCH_PHOTOS = "flickr.photos.search"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        
        static let BASE_PARAMETERS = [
            "api_key": API_KEY,
            "safe_search": SAFE_SEARCH,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK
        ]
    }
    
    // MARK: - General constants for use throughout the application
    
    static let documentsDirectory = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] )+"/"
}
