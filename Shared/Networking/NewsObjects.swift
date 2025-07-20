//
//  NewsObjects.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/31/24.
//

import Foundation

struct NodeDTO: Codable {
    let id: String
    let errorCount: Int64
    let isExpanded: Bool
    let type: NodeType
    let title: String
    let favIconURL: URL?
    let pinned: UInt8
    let favIcon: Data?
    let children: [NodeDTO]?
}

struct FolderDTO: Codable {
    let id: Int64
    let name: String
    let opened: Bool
    let feeds: [FeedDTO]
}

struct FoldersDTO: Codable {
    let folders: [FolderDTO]
}

struct FeedDTO: Codable {
    let ordering: Int64
    let url: String?
    let items: [ItemDTO]
    let id: Int64
    let added: Date
    let faviconLink: String?
    let lastUpdateError: String?
    let folderId: Int64?
    let pinned: Bool
    let link: String?
    let updateErrorCount: Int64
    let title: String?
    let unreadCount: Int64?
    let nextUpdateTime: Date?
}

struct FeedsDTO: Codable {
    let newestItemId: Int64
    let starredCount: Int64?
    let feeds: [FeedDTO]
}

struct ItemDTO: Codable {
    let mediaDescription: String?
    let title: String
    let unread: Bool
    let starred: Bool
    let fingerprint: String?
    let author: String?
    let feedId: Int64
    let enclosureLink: String?
    let body: String?
    let guid: String?
    let guidHash: String?
    let rtl: Bool
    let updatedDate: Date?
    let url: String?
    let pubDate: Date
    let enclosureMime: String?
    let mediaThumbnail: String?
    let id: Int64
    let lastModified: Date
    let contentHash: String?
}

struct ItemsDTO: Codable {
    let items: [ItemDTO]
}

struct NewsWarningsDTO: Codable {
    let improperlyConfiguredCron: Bool  // if true the webapp will fail to update the feeds correctly
    let incorrectDbCharset: Bool
}

struct NewsStatusDTO: Codable {
    let version: String
    let warnings: NewsWarningsDTO
}
