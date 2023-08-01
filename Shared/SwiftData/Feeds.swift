//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Feeds {
    var newestItemId: Int32
    var starredCount: Int32

    init(newestItemId: Int32, starredCount: Int32) {
        self.newestItemId = newestItemId
        self.starredCount = starredCount
    }
}
