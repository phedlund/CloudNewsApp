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
    #Index<Feed>([\.id], [\.folderId])

    var added: Date
    var faviconLink: String?
    var folderId: Int64
    @Attribute(.unique) var id: Int64
    var lastModified: Date
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

    // Parental relationship
    public var node: Node?

    @Relationship var items: [Item]

    @MainActor
    var favIconUrl: URL? {
        get async throws {
            return try await favIconUrl()
        }
    }

    nonisolated var folder: Folder? {
        let context = self.modelContext
        return context?.folder(id: folderId)
    }

    init(added: Date, faviconLink: String? = nil, folderId: Int64?, id: Int64, lastUpdateError: String? = nil, link: String? = nil, ordering: Int64, pinned: Bool, title: String? = nil, unreadCount: Int64, updateErrorCount: Int64, url: String? = nil, items: [Item]) {
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
        self.lastModified = Date()
        self.items = items
    }

    convenience init(item: FeedDTO) {
        self.init(added: item.added, 
                  faviconLink: item.faviconLink,
                  folderId: item.folderId,
                  id: item.id,
                  lastUpdateError: item.lastUpdateError,
                  link: item.link,
                  ordering: item.ordering,
                  pinned: item.pinned,
                  title: item.title,
                  unreadCount: item.unreadCount,
                  updateErrorCount: item.updateErrorCount,
                  url: item.url,
                  items: [Item]())
    }

    @MainActor
    private func favIconUrl() async throws -> URL? {
        let validSchemas = ["http", "https", "file"]
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

extension Feed {

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
