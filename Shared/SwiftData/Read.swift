//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Unread {
    @Attribute(.unique) var itemId: Int32

    init(itemId: Int32) {
        self.itemId = itemId
    }
}

@Model
final class Read {
    @Attribute(.unique) var itemId: Int32

    init(itemId: Int32) {
        self.itemId = itemId
    }
}
