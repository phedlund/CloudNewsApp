//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import SwiftData
import SwiftSoup
import SwiftUI

@Model
final class Item {
    #Index<Item>([\.id], [\.feedId])

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
    var lastModified: Date
    var mediaThumbnail: String?
    var mediaDescription: String?
    var pubDate: Date
    var rtl: Bool
    //    var readable: String?
    var starred: Bool
    var title: String?
    var unread: Bool
    var updatedDate: Date?
    var url: String?
    var thumbnailURL: URL?

    nonisolated var feed: Feed? {
        let context = self.modelContext
        return context?.feed(id: feedId)
    }

    init(author: String? = nil, body: String? = nil, contentHash: String? = nil, displayBody: String, displayTitle: String, dateFeedAuthor: String, enclosureLink: String? = nil, enclosureMime: String? = nil, feedId: Int64, fingerprint: String? = nil, guid: String? = nil, guidHash: String? = nil, id: Int64, lastModified: Date, mediaThumbnail: String? = nil, mediaDescription: String? = nil, pubDate: Date, rtl: Bool, starred: Bool, title: String? = nil, unread: Bool, updatedDate: Date? = nil, url: String? = nil, thumbnailURL: URL? = nil) {
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
        self.thumbnailURL = thumbnailURL
    }

    convenience init(item: ItemDTO) {

//        func internalUrl(_ urlString: String?) async -> URL? {
//            if let urlString, let url = URL(string: urlString) {
//                do {
//                    let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
//                    if let html = String(data: data, encoding: .utf8) {
//                        let doc: Document = try SwiftSoup.parse(html)
//                        if let meta = try doc.head()?.select("meta[property=og:image]").first() as? Element {
//                            let ogImage = try meta.attr("content")
//                            let ogUrl = URL(string: ogImage)
//                            return ogUrl
//                        } else if let meta = try doc.head()?.select("meta[property=twitter:image]").first() as? Element {
//                            let twImage = try meta.attr("content")
//                            let twUrl = URL(string: twImage)
//                            return twUrl
//                        } else {
//                            return nil
//                        }
//                    }
//                } catch(let error) {
//                    print(error.localizedDescription)
//                }
//            }
//            return nil
//        }

        let displayTitle = plainSummary(raw: item.title)

        var summary = ""
        if let body = item.body {
            summary = body
        } else if let mediaDescription = item.mediaDescription {
            summary = mediaDescription
        }
        if !summary.isEmpty {
            if summary.range(of: "<style>", options: .caseInsensitive) != nil {
                if summary.range(of: "</style>", options: .caseInsensitive) != nil {
                    if let start = summary.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                       let end = summary.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                        let sub = summary[start..<end]
                        summary = summary.replacingOccurrences(of: sub, with: "")
                    }
                }
            }
        }
        let displayBody = plainSummary(raw: summary)

        let clipLength = 50
        var dateLabelText = ""
        dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: item.pubDate))
        if !dateLabelText.isEmpty {
            dateLabelText.append(" | ")
        }

        if let itemAuthor = item.author,
           !itemAuthor.isEmpty {
            if itemAuthor.count > clipLength {
                dateLabelText.append(contentsOf: itemAuthor.filter( { !$0.isNewline }).prefix(clipLength))
                dateLabelText.append(String(0x2026))
            } else {
                dateLabelText.append(itemAuthor)
            }
        }

        let validSchemas = ["http", "https", "file"]
        var itemImageUrl: URL?
        if let urlString = item.mediaThumbnail, let imgUrl = URL(string: urlString) {
            itemImageUrl = imgUrl
        } else if let summary = item.body {
            do {
                let doc: Document = try SwiftSoup.parse(summary)
                let srcs: Elements = try doc.select("img[src]")
                let images = try srcs.array().map({ try $0.attr("src") })
                let filteredImages = images.filter({ validSchemas.contains(String($0.prefix(4))) })
                if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                    itemImageUrl = imgUrl
                } else {
//                    itemImageUrl = await internalUrl(item.url)
                }
            } catch Exception.Error(_, let message) { // An exception from SwiftSoup
                print(message)
            } catch(let error) {
                print(error.localizedDescription)
            }
        } else {
//            itemImageUrl = await internalUrl(item.url)
        }

        self.init(author: item.author,
                  body: item.body,
                  contentHash: item.contentHash,
                  displayBody: displayBody,
                  displayTitle: displayTitle,
                  dateFeedAuthor: dateLabelText,
                  enclosureLink: item.enclosureLink,
                  enclosureMime: item.enclosureMime,
                  feedId: item.feedId,
                  fingerprint: item.fingerprint,
                  guid: item.guid,
                  guidHash: item.guidHash,
                  id: item.id,
                  lastModified: item.lastModified,
                  mediaThumbnail: item.mediaThumbnail,
                  mediaDescription: item.mediaDescription,
                  pubDate: item.pubDate,
                  rtl: item.rtl,
                  starred: item.starred,
                  title: item.title,
                  unread: item.unread,
                  updatedDate: item.updatedDate,
                  url: item.url,
                  thumbnailURL: itemImageUrl)
    }

}

extension Item {

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
