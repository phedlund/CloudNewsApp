//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Feed {
    var added: Int64
    var faviconLink: String?
    var folderId: Int64
    @Attribute(.unique) var id: Int64
    var lastModified: Int64
    var lastUpdateError: String?
    var link: String?
    var ordering: Int64
    var pinned: Bool
    var preferWeb: Bool
    var title: String?
    var unreadCount: Int64
    var updateErrorCount: Int64
    var url: String?
    var useReader: Bool

    @Relationship
    var items: [Item]

    init(added: Int64, faviconLink: String? = nil, folderId: Int64?, id: Int64, lastUpdateError: String? = nil, link: String? = nil, ordering: Int64, pinned: Bool, title: String? = nil, unreadCount: Int64, updateErrorCount: Int64, url: String? = nil, items: [Item]) {
        self.added = added
        self.faviconLink = faviconLink
        self.folderId = folderId ?? 0
        self.id = id
        self.lastUpdateError = lastUpdateError
        self.link = link
        self.ordering = ordering
        self.pinned = pinned
        self.title = title
        self.unreadCount = unreadCount
        self.updateErrorCount = updateErrorCount
        self.url = url

        self.preferWeb = false
        self.useReader = false
        self.lastModified = Int64(Date().timeIntervalSince1970)
        self.items = items
    }
}

extension Feed: Decodable {
    enum CodingKeys: String, CodingKey {
        case added = "added"
        case faviconLink = "faviconLink"
        case folderId = "folderId"
        case id = "id"
        case lastUpdateError = "lastUpdateError"
        case link = "link"
        case ordering = "ordering"
        case pinned = "pinned"
        case title = "title"
        case unreadCount = "unreadCount"
        case updateErrorCount = "updateErrorCount"
        case url = "url"
    }

    convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let added = try values.decode(Int64.self, forKey: .added)
        let faviconLink = try values.decodeIfPresent(String.self, forKey: .faviconLink)
        var folderId: Int64 = 0
        if let fId = try values.decodeIfPresent(Int64.self, forKey: .folderId) {
            folderId = fId
        }
        let id = try values.decode(Int64.self, forKey: .id)
        let lastUpdateError = try values.decodeIfPresent(String.self, forKey: .lastUpdateError)
        let link = try values.decodeIfPresent(String.self, forKey: .link)
        let ordering = try values.decode(Int64.self, forKey: .ordering)
        let pinned = try values.decode(Bool.self, forKey: .pinned)
        let title = try values.decodeIfPresent(String.self, forKey: .title)
        var unreadCount: Int64 = 0
        if let uCount = try values.decodeIfPresent(Int64.self, forKey: .unreadCount) {
            unreadCount = uCount
        }
        let updateErrorCount = try values.decode(Int64.self, forKey: .updateErrorCount)
        let url = try values.decodeIfPresent(String.self, forKey: .url)
        self.init(added: added, faviconLink: faviconLink, folderId: folderId, id: id, lastUpdateError: lastUpdateError, link: link, ordering: ordering, pinned: pinned, title: title, unreadCount: unreadCount, updateErrorCount: updateErrorCount, url: url, items: [Item]())
    }

}

extension Feed {
    static func all() -> [Feed]? {
        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
//        let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned)
        let descriptor = FetchDescriptor<Feed>(sortBy: [idSortDescriptor])
        if let container = NewsData.shared.container {
            let context = ModelContext(container)
            do {
                return try context.fetch(descriptor)
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return nil
    }

    static func feed(id: Int64) -> Feed? {
        let predicate = #Predicate<Feed>{ $0.id == id }

        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let container = NewsData.shared.container {
            let context = ModelContext(container)
            do {
                let results  = try context.fetch(descriptor)
                return results.first
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return nil
    }

    static func inFolder(folder: Int64) -> [Feed]? {
        let predicate = #Predicate<Feed>{ $0.folderId == folder }

        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        //let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned, order: .forward)
        let descriptor = FetchDescriptor<Feed>(predicate: predicate, sortBy: [idSortDescriptor])
        if let container = NewsData.shared.container {
            let context = ModelContext(container)
            do {
                return try context.fetch(descriptor)
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return nil
    }

    static func idsInFolder(folder: Int64) -> [Int64]? {
        if let feeds = Feed.inFolder(folder: folder) {
            return feeds.map { $0.id }
        }
        return nil
    }

}
