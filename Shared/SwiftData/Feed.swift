//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import Nuke
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

    var favIconUrl: URL? {
        get async throws {
            return try await favIconUrl()
        }
    }

    private let validSchemas = ["http", "https", "file"]

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

    private func favIconUrl() async throws -> URL? {
        var itemImageUrl: URL?
        if let link = faviconLink,
           let url = URL(string: link),
           let scheme = url.scheme,
           validSchemas.contains(scheme) {
            itemImageUrl = url
        } else {
            if let feedUrl = URL(string: link ?? "data:null"),
               let host = feedUrl.host,
               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                itemImageUrl = url
            }
        }
        return itemImageUrl
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

    
    @MainActor
    static func delete(id: Int64) async throws {
        if let container = NewsData.shared.container {
            do {
                try container.mainContext.delete(model: Feed.self, where: #Predicate { $0.id == id } )
                try container.mainContext.save()
            } catch {
//                self.logger.debug("Failed to execute items insert request.")
                throw DatabaseError.feedErrorDeleting
            }
        }
    }

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
