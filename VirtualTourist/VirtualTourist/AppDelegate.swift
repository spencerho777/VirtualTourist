//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/5/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import UIKit
import MapKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let dataController = DataController(modelName: "VirtualTourist")
    
    func checkFirstLaunch() {
        if UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            debugPrint("Good to go")
        } else {
            debugPrint("First Launch")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            let defaultRegion: [String: Double] = ["latitude": 37.13284, "longitude": -95.78558, "latitudeDelta": 75.41927, "longitudeDelta": 61.27601]
            
            UserDefaults.standard.set(defaultRegion, forKey: "mapRegion")
            UserDefaults.standard.synchronize()
        }
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        checkFirstLaunch()
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        dataController.load()
        
        let navigationController = window?.rootViewController as! UINavigationController
        let mapViewController = navigationController.topViewController as! MapViewController
        mapViewController.dataController = dataController
        
        return true
    }
}

