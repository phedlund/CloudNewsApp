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

extension Item: Decodable {

    enum CodingKeys: String, CodingKey {
        case author = "author"
        case dateFeedAuthor = "dateFeedAuthor"
        case body = "body"
        case displayBody = "displayBody"
        case enclosureLink = "enclosureLink"
        case enclosureMime = "enclosureMime"
        case feedId = "feedId"
        case fingerprint = "fingerprint"
        case guid = "guid"
        case guidHash = "guidHash"
        case id = "id"
        case lastModified = "lastModified"
        case mediaThumbnail = "mediaThumbnail"
        case mediaDescription = "mediaDescription"
        case pubDate = "pubDate"
        case rtl = "rtl"
        case starred = "starred"
        case title = "title"
        case displayTitle = "displayTitle"
        case unread = "unread"
        case updatedDate = "updatedDate"
        case url = "url"
    }

    convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let author = try values.decodeIfPresent(String.self, forKey: .author)
        let dateFeedAuthor = try values.decodeIfPresent(String.self, forKey: .dateFeedAuthor) ?? ""
        let body = try values.decodeIfPresent(String.self, forKey: .body)
        let displayBody = try values.decodeIfPresent(String.self, forKey: .displayBody) ?? ""
        let enclosureLink = try values.decodeIfPresent(String.self, forKey: .enclosureLink)
        let enclosureMime = try values.decodeIfPresent(String.self, forKey: .enclosureMime)
        let feedId = try values.decode(Int64.self, forKey: .feedId)
        let fingerprint = try values.decodeIfPresent(String.self, forKey: .fingerprint)
        let guid = try values.decodeIfPresent(String.self, forKey: .guid)
        let guidHash = try values.decodeIfPresent(String.self, forKey: .guidHash)
        let id = try values.decode(Int64.self, forKey: .id)
        let lastModified = try values.decode(Int64.self, forKey: .lastModified)
        let mediaThumbnail = try values.decodeIfPresent(String.self, forKey: .mediaThumbnail)
        let mediaDescription = try values.decodeIfPresent(String.self, forKey: .mediaDescription)
        let pubDate = try values.decode(Int64.self, forKey: .pubDate)
        let rtl = try values.decode(Bool.self, forKey: .rtl)
        let starred = try values.decode(Bool.self, forKey: .starred)
        let title = try values.decodeIfPresent(String.self, forKey: .title)
        let displayTitle = try values.decodeIfPresent(String.self, forKey: .displayTitle) ?? ""
        let unread = try values.decode(Bool.self, forKey: .unread)
        let updatedDate = try values.decodeIfPresent(Int64.self, forKey: .updatedDate) ?? 0
        let url = try values.decodeIfPresent(String.self, forKey: .url)
        self.init(author: author, body: body, contentHash: nil, displayBody: displayBody, displayTitle: displayTitle, dateFeedAuthor: dateFeedAuthor, enclosureLink: enclosureLink, enclosureMime: enclosureMime, feedId: feedId, fingerprint: fingerprint, guid: guid, guidHash: guidHash, id: id, lastModified: lastModified, mediaThumbnail: mediaThumbnail, mediaDescription: mediaDescription, pubDate: pubDate, rtl: rtl, starred: starred, title: title, unread: unread, updatedDate: updatedDate, url: url)
    }

}
