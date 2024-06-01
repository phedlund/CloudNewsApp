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
    @Attribute(.unique) var id: Int64
    var opened: Bool
    var lastModified: Date
    var name: String?
    @Attribute(.ephemeral) var unreadCount: Int64 = 0

    // Parental relationship
    public var node: NodeModel?

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

extension Folder: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
    }

    convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let inId = try values.decode(Int64.self, forKey: .id)
        let inName = try values.decodeIfPresent(String.self, forKey: .name)
        self.init(id: inId, opened: false, lastModified: Date(), name: inName, feeds: [Feed]())
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
