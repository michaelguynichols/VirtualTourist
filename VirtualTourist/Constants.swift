//
//  Constants.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/10/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import Foundation

extension FlickrAPI {
    
    struct URLs {
        static let BASE_URL = "https://api.flickr.com/services/rest/"
    }
    
    struct METHODARGS {
        
        // Method
        static let METHOD_NAME = "flickr.photos.search"
        
        // Method arguments for photo search
        static let EXTRAS = "url_m"
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let SAFE_SEARCH = "safe_search"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0

    }
    
    struct APIKEY {
        static let API_KEY = "672d6269dad2b175f45cd863bacb5053"
    }
    
}