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
    var folderId: Int64? = 0
    @Attribute(.unique) var id: Int64
    var lastModified: Int64 = Int64(Date().timeIntervalSince1970)
    var lastUpdateError: String?
    var link: String?
    var ordering: Int64
    var pinned: Bool
    var preferWeb: Bool = false
    var title: String?
    var unreadCount: Int64
    var updateErrorCount: Int64
    var url: String?
    var useReader: Bool = false

    @Relationship(.cascade)
    var items: [Item] = [Item]()

    init(added: Int64, faviconLink: String? = nil, folderId: Int64? = nil, id: Int64, lastUpdateError: String? = nil, link: String? = nil, ordering: Int64, pinned: Bool, title: String? = nil, unreadCount: Int64, updateErrorCount: Int64, url: String? = nil, items: [Item]) {
        self.added = added
        self.faviconLink = faviconLink
        self.folderId = folderId
        self.id = id
        self.lastUpdateError = lastUpdateError
        self.link = link
        self.ordering = ordering
        self.pinned = pinned
        self.title = title
        self.unreadCount = unreadCount
        self.updateErrorCount = updateErrorCount
        self.url = url
        self.items = items
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
