//
//  Item.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
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
