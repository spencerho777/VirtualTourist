//
//  Pin+Extensions.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/21/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import Foundation
import MapKit

extension Pin: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        
        let latDegrees = CLLocationDegrees(self.latitude)
        let longDegrees = CLLocationDegrees(self.longitude)
        return CLLocationCoordinate2D(latitude: latDegrees, longitude: longDegrees)
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        creationDate = Date()
    }
    
}
