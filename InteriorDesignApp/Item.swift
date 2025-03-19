//
//  Item.swift
//  InteriorDesignApp
//
//  Created by Maxwell Miao on 2025-03-17.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
