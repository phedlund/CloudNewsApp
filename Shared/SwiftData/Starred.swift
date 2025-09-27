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
    @Attribute(.unique) var itemId: Int64

    init(itemId: Int64) {
        self.itemId = itemId
    }
}

@Model
nonisolated final class Starred {
    @Attribute(.unique) var itemId: Int64

    init(itemId: Int64) {
        self.itemId = itemId
    }
}
