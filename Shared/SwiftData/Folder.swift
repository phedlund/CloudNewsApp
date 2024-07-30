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
    var opened: Bool
    var lastModified: Date
    var name: String?
    @Attribute(.ephemeral) var unreadCount: Int64 = 0

    // Parental relationship
    public var node: Node?

    @Relationship var feeds: [Feed]

    init(id: Int64, opened: Bool, lastModified: Date, name: String? = nil, feeds: [Feed]) {
        self.id = id
        self.opened = opened
        self.lastModified = lastModified
        self.name = name
        self.unreadCount = 0
        self.feeds = feeds
    }

    convenience init(item: FolderDTO) {
        self.init(id: item.id, 
                  opened: item.opened,
                  lastModified: Date(),
                  name: item.name,
                  feeds: [Feed]())
    }
}

extension Folder: Identifiable { }

extension Folder {

    static func reset() {
//        TODO NewsData.shared.container.viewContext.performAndWait {
//            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
//            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
//            do {
//                try NewsData.shared.container.viewContext.executeAndMergeChanges(using: deleteRequest)
//            } catch {
//                let updateError = error as NSError
//                print("\(updateError), \(updateError.userInfo)")
//            }
//        }
    }

}
