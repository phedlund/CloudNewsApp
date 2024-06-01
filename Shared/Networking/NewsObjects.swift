//
//  NewsObjects.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/31/24.
//

import Foundation

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
    let unreadCount: Int64
}

struct FeedsDTO: Codable {
    let newestItemId: Int64
    let starredCount: Int64
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

