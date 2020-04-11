//
//  Photo+Extensions.swift
//  VirtualTourist
//
//  Created by Van Nguyen on 1/17/19.
//  Copyright © 2019 Spencer Ho's Hose. All rights reserved.
//

import Foundation
import CoreData

extension Photo {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        downloadDate = Date()
    }
}
