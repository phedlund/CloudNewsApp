//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Unstarred {
    @Attribute(.unique) var itemIdData: Data

    init(itemIdData: Data) {
        self.itemIdData = itemIdData
    }
}

@Model
final class Starred {
    @Attribute(.unique) var itemIdData: Data

    init(itemIdData: Data) {
        self.itemIdData = itemIdData
    }
}
