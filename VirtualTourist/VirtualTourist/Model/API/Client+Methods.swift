//
//  Client+Methods.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/21/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import Foundation
import UIKit

class Client: NSObject{
    
    var session = URLSession.shared
    
    override init() {
        super.init()
    }
    
    func searchPhotosByLocation(latitude: Double, longitude: Double, completionHandlerForSearch: @escaping (_ success: Bool, _ errorString: String?, _ reults: [String]?) -> Void){
        
        let methodParameters = [Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
                                Constants.FlickrParameterKeys.PerPage : Constants.FlickrParameterValues.PerPage,
                                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                                Constants.FlickrParameterKeys.BoundingBox: bboxString(latitude: latitude, longitude: longitude),
                                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback] as [String:AnyObject]
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            let photosDictionaryReturn = self.getPhotosDictionary(data: data, response: response, error: error)
            
            if let error = photosDictionaryReturn.1 {
                completionHandlerForSearch(false, error, nil)
                return
            }
            
            let photosDictionary = photosDictionaryReturn.0!
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                completionHandlerForSearch(false, "Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)", nil)
                return
            }
            
            // pick a random page!
            let pageLimit = min(totalPages, 4000 / Int(Constants.FlickrParameterValues.PerPage)!)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            self.searchPhotosByLocation(methodParameters, pageNumber: randomPage) { (success, errorString, results) in
                completionHandlerForSearch(success, errorString, results)
            }
        }
        
        // start the task!
        task.resume()
    }
    
    func searchPhotosByLocation(_ methodParameters: [String: AnyObject], pageNumber: Int, completionHandlerForSearch: @escaping (_ success: Bool, _ errorString: String?, _ results: [String]?) -> Void) {
        
        var methodParametersWithPageNumber = methodParameters
        methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = pageNumber as AnyObject?
        let request = URLRequest(url: flickrURLFromParameters(methodParametersWithPageNumber))
        
        let task = session.dataTask(with: request) { (data, response, error) in
            
            let photosDictionaryReturn = self.getPhotosDictionary(data: data, response: response, error: error)
            
            if let error = photosDictionaryReturn.1 {
                completionHandlerForSearch(false, error, nil)
                return
            }
            
            let photosDictionary = photosDictionaryReturn.0!
            
            /* GUARD: Is the "photo" key in photosDictionary? */
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                completionHandlerForSearch(false, "Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)", nil)
                return
            }
            
            var photoURLArray: [String] = []
            for photo in photosArray {
                if let url = photo["url_m"] {
                    photoURLArray.append(url as! String)
                }
            }
            
            completionHandlerForSearch(true, nil, photoURLArray)
        }
        
        task.resume()
    }
    
    func getPhotosDictionary(data: Data?, response: URLResponse?, error: Error?) -> ([String:AnyObject]?, String?) {
        
        func handleError(_ error: String) -> ([String:AnyObject]?, String?){
            return (nil, error)
        }
        
        guard error == nil else {
            return handleError("Error in request: \(error!)")
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
            return handleError("Request returned a status code other than 2xx!")
        }
        guard let data = data else {
            return handleError("No data was returned by the request!")
        }
        
        let parsedResult: [String:AnyObject]!
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject]
        } catch {
            return handleError("Could not parse the data as JSON: '\(data)'")
        }
        
        guard let status = parsedResult[Constants.FlickrResponseKeys.Status] as? String, status == Constants.FlickrResponseValues.OKStatus else {
            return handleError("Flickr API returned an error. See error code and message in \(parsedResult!)")
        }
        
        /* GUARD: Is "photos" key in our result? */
        guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
            return handleError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult!)")
        }
        
        return (photosDictionary, nil)
    }

    private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
    
    private func bboxString(latitude: Double, longitude: Double) -> String {
        // ensure bbox is bounded by minimum and maximums
        let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
    }
    
    class func sharedInstance() -> Client {
        struct Singleton {
            static var sharedInstance = Client()
        }
        return Singleton.sharedInstance
    }
    
}
