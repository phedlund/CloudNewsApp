//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Folder {
    #Index<Folder>([\.id])

    @Attribute(.unique) var id: Int64
    var name: String?
    var opened: Bool
    @Relationship var feeds: [Feed]

    init(id: Int64, opened: Bool, name: String? = nil, feeds: [Feed]) {
        self.id = id
        self.opened = opened
        self.name = name
        self.feeds = feeds
    }

    convenience init(item: FolderDTO) {
        self.init(id: item.id, 
                  opened: item.opened,
                  name: item.name,
                  feeds: [Feed]())
    }
}

extension Folder: Identifiable { }
