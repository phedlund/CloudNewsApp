//
//  DataModels.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/8/23.
//

import Foundation
import Nuke
import SwiftData
import SwiftSoup

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

    @Transient var webViewHelper = ItemWebViewHelper()

    private let validSchemas = ["http", "https", "file"]

    var itemImage: SystemImage {
        get async throws {
            guard let url = try await imageUrl() else {
                return SystemImage()
            }
            return try await ImagePipeline.shared.image(for: url)
        }
    }

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

    private func imageUrl() async throws -> URL? {
        var itemImageUrl: URL?
        if let urlString = mediaThumbnail, let imgUrl = URL(string: urlString) {
            itemImageUrl = imgUrl
        } else if let summary = body {
            do {
                let doc: Document = try SwiftSoup.parse(summary)
                let srcs: Elements = try doc.select("img[src]")
                let images = try srcs.array().map({ try $0.attr("src") })
                let filteredImages = images.filter({ validSchemas.contains(String($0.prefix(4))) })
                if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                    itemImageUrl = imgUrl
                } else if let stepTwoUrl = await stepTwo() {
                    itemImageUrl = stepTwoUrl
                }
            } catch Exception.Error(_, let message) { // An exception from SwiftSoup
                print(message)
            } catch(let error) {
                print(error.localizedDescription)
            }
        } else {
            itemImageUrl = await stepTwo()
        }
        return itemImageUrl
    }

    private func stepTwo() async -> URL? {
        if let urlString = url, let url = URL(string: urlString) {
            do {
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                if let html = String(data: data, encoding: .utf8) {
                    let doc: Document = try SwiftSoup.parse(html)
                    if let meta = try doc.head()?.select("meta[property=og:image]").first() as? Element {
                        let ogImage = try meta.attr("content")
                        let ogUrl = URL(string: ogImage)
                        return ogUrl
                    } else if let meta = try doc.head()?.select("meta[property=twitter:image]").first() as? Element {
                        let twImage = try meta.attr("content")
                        let twUrl = URL(string: twImage)
                        return twUrl
                    } else {
                        return nil
                    }
                }
            } catch(let error) {
                print(error.localizedDescription)
            }
        }
        return nil
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

    @MainActor
    static func deleteItems(with feedId: Int64) async throws {
        if let container = NewsData.shared.container {
            do {
                try container.mainContext.delete(model: Item.self, where: #Predicate { $0.feedId == feedId } )
                try container.mainContext.save()
            } catch {
//                self.logger.debug("Failed to execute items insert request.")
                throw DatabaseError.itemErrorDeleting
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
