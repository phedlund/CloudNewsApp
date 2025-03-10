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
    var newestItemId: Int64
    var starredCount: Int64?

    init(newestItemId: Int64, starredCount: Int64?) {
        self.newestItemId = newestItemId
        self.starredCount = starredCount
    }
}
