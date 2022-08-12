//
//  Item.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation
import SwiftSoup

struct Item: Codable, ItemProtocol {
    var author : String?
    var body : String?
    var enclosureLink : String?
    var enclosureMime : String?
    var feedId : Int32
    var fingerprint : String?
    var guid : String?
    var guidHash : String?
    var id : Int32
    var lastModified : Int32
    var mediaThumbnail: String?
    var mediaDescription: String?
    var pubDate : Int32
    var rtl: Bool
    var starred : Bool
    var title : String
    var unread : Bool
    var url : String?
    
    enum CodingKeys: String, CodingKey {
        case author = "author"
        case body = "body"
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
        case unread = "unread"
        case url = "url"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        author = try values.decodeIfPresent(String.self, forKey: .author)
        body = try values.decodeIfPresent(String.self, forKey: .body)
        enclosureLink = try values.decodeIfPresent(String.self, forKey: .enclosureLink)
        enclosureMime = try values.decodeIfPresent(String.self, forKey: .enclosureMime)
        feedId = try values.decode(Int32.self, forKey: .feedId)
        fingerprint = try values.decodeIfPresent(String.self, forKey: .fingerprint)
        guid = try values.decodeIfPresent(String.self, forKey: .guid)
        guidHash = try values.decodeIfPresent(String.self, forKey: .guidHash)
        id = try values.decode(Int32.self, forKey: .id)
        lastModified = try values.decode(Int32.self, forKey: .lastModified)
        mediaThumbnail = try values.decodeIfPresent(String.self, forKey: .mediaThumbnail)
        mediaDescription = try values.decodeIfPresent(String.self, forKey: .mediaDescription)
        pubDate = try values.decode(Int32.self, forKey: .pubDate)
        rtl = try values.decode(Bool.self, forKey: .rtl)
        starred = try values.decode(Bool.self, forKey: .starred)
        title = itemDisplayTitle(try values.decodeIfPresent(String.self, forKey: .title))
        unread = try values.decode(Bool.self, forKey: .unread)
        url = try values.decodeIfPresent(String.self, forKey: .url)
    }

    func asDictionary() -> [String: Any] {
        return [CodingKeys.author.stringValue: self.author as Any,
                CodingKeys.body.stringValue: self.body as Any,
                "displayBody": itemDisplayBody(self.body, mediaDescription: self.mediaDescription),
                CodingKeys.enclosureLink.stringValue: self.enclosureLink as Any,
                CodingKeys.enclosureMime.stringValue: self.enclosureMime as Any,
                CodingKeys.feedId.stringValue: self.feedId as Any,
                CodingKeys.guid.stringValue: self.guid as Any,
                CodingKeys.guidHash.stringValue: self.guidHash as Any,
                CodingKeys.id.stringValue: self.id,
                CodingKeys.lastModified.stringValue: self.lastModified as Any,
                CodingKeys.mediaThumbnail.stringValue: self.mediaThumbnail as Any,
                CodingKeys.mediaDescription.stringValue: self.mediaDescription as Any,
                CodingKeys.pubDate.stringValue: self.pubDate,
                CodingKeys.rtl.stringValue: self.rtl as Any,
                CodingKeys.starred.stringValue: self.starred,
                CodingKeys.title.stringValue: self.title as Any,
                CodingKeys.unread.stringValue: self.unread,
                CodingKeys.url.stringValue: self.url as Any
        ]
    }

}

func itemDisplayTitle(_ title: String?) -> String {
    guard let titleValue = title else {
        return "Untitled"
    }

    return plainSummary(raw: titleValue as String)
}

func itemDisplayBody(_ body: String?, mediaDescription: String?) -> String {
    var displayBody = ""
    if let summaryBody = body {
        displayBody = summaryBody
    } else if let summaryBody = mediaDescription {
        displayBody = summaryBody
    }

    if !displayBody.isEmpty {
        if displayBody.range(of: "<style>", options: .caseInsensitive) != nil {
            if displayBody.range(of: "</style>", options: .caseInsensitive) != nil {
                if let start = displayBody.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                   let end = displayBody.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                    let sub = displayBody[start..<end]
                    displayBody = displayBody.replacingOccurrences(of: sub, with: "")
                }
            }
        }
        return  plainSummary(raw: displayBody)
    } else {
        return ""
    }
}

private func plainSummary(raw: String) -> String {
    guard let doc: Document = try? SwiftSoup.parse(raw) else {
        return raw
    } // parse html
    guard let txt = try? doc.text() else {
        return raw
    }
    return txt
}
