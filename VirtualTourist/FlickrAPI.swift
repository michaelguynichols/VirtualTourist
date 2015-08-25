//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/10/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import Foundation

class FlickrAPI: NSObject {
    
    var latitude: Double
    var longitude: Double
    var session: NSURLSession
    
    init(lat: Double, lon: Double) {
        session = NSURLSession.sharedSession()
        
        latitude = lat
        longitude = lon
    }
    
    // Helper function to parse JSON data.
    func parseJSONResult(data: NSData) -> NSDictionary?  {
        var parsingError: NSError? = nil
        let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
        return parsedResult
    }
    
    func search(completionHandler: (result: AnyObject!, error: NSError?) -> Void)  {
        
        self.getPageNumbers() {JSONResult, error in
            
            if let error = error {
                println("Error")
            } else {
        
                let methodArguments: [String: AnyObject] = [
                    "method": FlickrAPI.METHODARGS.METHOD_NAME,
                    "api_key": FlickrAPI.APIKEY.API_KEY,
                    "bbox": self.createBoundingBoxString(),
                    "safe_search": FlickrAPI.METHODARGS.SAFE_SEARCH,
                    "extras": FlickrAPI.METHODARGS.EXTRAS,
                    "format": FlickrAPI.METHODARGS.DATA_FORMAT,
                    "nojsoncallback": FlickrAPI.METHODARGS.NO_JSON_CALLBACK,
                    "per_page": 102,
                    "page": JSONResult
                ]
        
                let urlString = FlickrAPI.URLs.BASE_URL + self.escapedParameters(methodArguments)
                let url = NSURL(string: urlString)!
                println(url)
                let request = NSURLRequest(URL: url)
        
                let task = self.session.dataTaskWithRequest(request) {data, response, error in
                    if error != nil {
                        // Handle error
                        completionHandler(result: nil, error: NSError(domain: "Download", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download Error"]))
                    } else {
                        if let result = self.parseJSONResult(data) {
                            if let photosDict = result["photos"] as? NSDictionary {
                                if let photosArray = photosDict["photo"] as? [[String: AnyObject]] {
                                    completionHandler(result: photosArray, error: nil)
                                }
                            }
                        }
                    }
                }
                task.resume()
                // return task
            }
        }
        
        // return NSURLSessionDataTask()
        
    }
    
    func getPageNumbers(completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        var pageCount = 0
        
        let methodArguments = [
            "method": FlickrAPI.METHODARGS.METHOD_NAME,
            "api_key": FlickrAPI.APIKEY.API_KEY,
            "bbox": createBoundingBoxString(),
            "safe_search": FlickrAPI.METHODARGS.SAFE_SEARCH,
            "extras": FlickrAPI.METHODARGS.EXTRAS,
            "format": FlickrAPI.METHODARGS.DATA_FORMAT,
            "nojsoncallback": FlickrAPI.METHODARGS.NO_JSON_CALLBACK
        ]
        
        let session = NSURLSession.sharedSession()
        let urlString = FlickrAPI.URLs.BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, error in
            if error != nil {
                // Handle error
                completionHandler(result: nil, error: NSError(domain: "Download", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download Error"]))
            } else {
                if let result = self.parseJSONResult(data) {
                    if let photos = result["photos"] as? NSDictionary {
                        if let numPages = photos["pages"] as? Double {
                            var randomPage = Int(arc4random_uniform(UInt32(numPages)))
                            completionHandler(result: randomPage, error: nil)
                        } else {
                            completionHandler(result: nil, error: NSError(domain: "Download", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download Error"]))
                        }
                    }
                }
            }
        }
        task.resume()
        return task
    }
    
    func taskForImage(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let request = NSURLRequest(URL: NSURL(string: filePath)!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                completionHandler(imageData: nil, error: NSError(domain: "Download", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download Error"]))
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }

    
    func escapedParameters(parameters: [String: AnyObject]) -> String {
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
    func createBoundingBoxString() -> String {
        
        /* Fix added to ensure box is bounded by minimum and maximum */
        let bottom_left_lon = max(longitude - FlickrAPI.METHODARGS.BOUNDING_BOX_HALF_WIDTH, FlickrAPI.METHODARGS.LON_MIN)
        let bottom_left_lat = max(latitude - FlickrAPI.METHODARGS.BOUNDING_BOX_HALF_HEIGHT, FlickrAPI.METHODARGS.LAT_MIN)
        let top_right_lon = min(longitude + FlickrAPI.METHODARGS.BOUNDING_BOX_HALF_HEIGHT, FlickrAPI.METHODARGS.LON_MAX)
        let top_right_lat = min(latitude + FlickrAPI.METHODARGS.BOUNDING_BOX_HALF_HEIGHT, FlickrAPI.METHODARGS.LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
}