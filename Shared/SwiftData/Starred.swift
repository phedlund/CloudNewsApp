//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
nonisolated final class Unstarred {
    @Attribute(.unique) var itemIdData: Data

    init(itemIdData: Data) {
        self.itemIdData = itemIdData
    }
}

@Model
nonisolated final class Starred {
    @Attribute(.unique) var itemIdData: Data

    init(itemIdData: Data) {
        self.itemIdData = itemIdData
    }
}
