//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Feed {
    #Index<Feed>([\.id], [\.folderId])

    var added: Date
    var faviconLink: String?
    var folderId: Int64
    @Attribute(.unique) var id: Int64
    var lastUpdateError: String?
    var link: String?
    var nextUpdateTime: Date?
    var ordering: Int64
    var pinned: Bool
    var preferWeb: Bool
    var title: String?
    var unreadCount: Int64
    var updateErrorCount: Int64
    var url: String?
    var useReader: Bool
    var favIconURL: URL?
    @Attribute(.externalStorage) var favIcon: Data?

    @Relationship var items: [Item]

    init(added: Date, faviconLink: String? = nil, folderId: Int64?, id: Int64, lastUpdateError: String? = nil, link: String? = nil, nextUpdateTime: Date? = nil, ordering: Int64, pinned: Bool, title: String? = nil, unreadCount: Int64, updateErrorCount: Int64, url: String? = nil, favIconURL: URL? = nil, favicon: Data? = nil, items: [Item]) {
        self.added = added
        self.faviconLink = faviconLink
        self.folderId = folderId ?? 0
        self.id = id
        self.lastUpdateError = lastUpdateError
        self.link = link
        self.nextUpdateTime = nextUpdateTime
        self.ordering = ordering
        self.pinned = pinned
        self.title = title
        self.unreadCount = unreadCount
        self.updateErrorCount = updateErrorCount
        self.url = url

        self.preferWeb = false
        self.useReader = false
        self.favIconURL = favIconURL
        self.favIcon = favicon
        self.items = items
    }

    convenience init(item: FeedDTO) async {
        let validSchemas = ["http", "https", "file"]
        var itemImageUrl: URL?
        if let faviconLink = item.faviconLink,
           let url = URL(string: faviconLink),
           let scheme = url.scheme,
           validSchemas.contains(scheme) {
            itemImageUrl = url
        } else {
            if let feedUrl = URL(string: item.link ?? "data:null"),
               let host = feedUrl.host,
               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                itemImageUrl = url
            }
        }

        var imageData: Data?
        if let itemImageUrl {
            do {
                let (data, _) = try await URLSession.shared.data(from: itemImageUrl)
                imageData = data
            } catch {
                print("Error fetching data: \(error)")
            }
        }

        self.init(added: item.added,
                  faviconLink: item.faviconLink,
                  folderId: item.folderId,
                  id: item.id,
                  lastUpdateError: item.lastUpdateError,
                  link: item.link,
                  nextUpdateTime: item.nextUpdateTime,
                  ordering: item.ordering,
                  pinned: item.pinned,
                  title: item.title,
                  unreadCount: item.unreadCount ?? 0,
                  updateErrorCount: item.updateErrorCount,
                  url: item.url,
                  favIconURL: itemImageUrl,
                  favicon: imageData,
                  items: [Item]())
    }

}
