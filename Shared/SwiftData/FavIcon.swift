//
//  FavIcon.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/21/25.
//

import Foundation
import SwiftData

@Model
nonisolated final class FavIcon {
    @Attribute(.unique) var id: Int64 // This maps to a feed's id

    var url: URL?
    @Attribute(.externalStorage) var icon: Data?

    init(id: Int64, url: URL? = nil, icon: Data? = nil) {
        self.id = id
        self.url = url
        self.icon = icon
    }

    convenience init(item: FavIconDTO) async {
        self.init(id: item.id,
                  url: item.url,
                  icon: item.icon)
    }

}
