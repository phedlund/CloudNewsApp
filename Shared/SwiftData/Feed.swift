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
    public var node: NodeModel?

    @Relationship var items: [Item]

    nonisolated var favIconUrl: URL? {
        get async throws {
            return try await favIconUrl()
        }
    }

    nonisolated var folder: Folder? {
        let context = self.modelContext
        return context?.folder(id: folderId)
    }

    private let validSchemas = ["http", "https", "file"]

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
/*
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
*/
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
