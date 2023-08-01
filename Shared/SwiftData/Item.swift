//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var author: String?
    var body: String?
    var contentHash: String?
    var displayBody: String
    var displayTitle: String
    var dateFeedAuthor: String
    var enclosureLink: String?
    var enclosureMime: String?
    var feedId: Int64
    var fingerprint: String?
    var guid: String?
    var guidHash: String?
    @Attribute(.unique) var id: Int64
    var lastModified: Int64
    var mediaThumbnail: String?
    var mediaDescription: String?
    var pubDate: Int64
    var rtl: Bool
    //    var readable: String?
    var starred: Bool
    var title: String?
    var unread: Bool
    var updatedDate: Int64?
    var url: String?

//    @Attribute(.transient) var webViewHelper = ItemWebViewHelper()

    init(author: String? = nil, body: String? = nil, contentHash: String? = nil, displayBody: String, displayTitle: String, dateFeedAuthor: String, enclosureLink: String? = nil, enclosureMime: String? = nil, feedId: Int64, fingerprint: String? = nil, guid: String? = nil, guidHash: String? = nil, id: Int64, lastModified: Int64, mediaThumbnail: String? = nil, mediaDescription: String? = nil, pubDate: Int64, rtl: Bool, starred: Bool, title: String? = nil, unread: Bool, updatedDate: Int64? = nil, url: String? = nil) {
        self.author = author
        self.body = body
        self.contentHash = contentHash
        self.displayBody = displayBody
        self.displayTitle = displayTitle
        self.dateFeedAuthor = dateFeedAuthor
        self.enclosureLink = enclosureLink
        self.enclosureMime = enclosureMime
        self.feedId = feedId
        self.fingerprint = fingerprint
        self.guid = guid
        self.guidHash = guidHash
        self.id = id
        self.lastModified = lastModified
        self.mediaThumbnail = mediaThumbnail
        self.mediaDescription = mediaDescription
        self.pubDate = pubDate
        self.rtl = rtl
        self.starred = starred
        self.title = title
        self.unread = unread
        self.updatedDate = updatedDate
        self.url = url
    }
}
