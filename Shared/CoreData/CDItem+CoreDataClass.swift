//
//  CDItem+CoreDataClass.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import CoreData
import SwiftSoup
import SwiftUI

@objc(CDItem)
public class CDItem: NSManagedObject, ItemProtocol {

    static private let entityName = "CDItem"

    @objc dynamic var dateAuthorFeed: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long

        var dateLabelText = ""
        let date = Date(timeIntervalSince1970: TimeInterval(pubDate))
        let currentLocale = Locale.current
        let dateComponents = "MMM d"
        let dateFormatString = DateFormatter.dateFormat(fromTemplate: dateComponents, options: 0, locale: currentLocale)
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = dateFormatString
        dateLabelText = dateLabelText + dateFormat.string(from: date)

        if dateLabelText.count > 0 {
            dateLabelText = dateLabelText  + " | "
        }

        if let author = author {
            if author.count > 0 {
                let clipLength =  50
                if author.count > clipLength {
                    dateLabelText = dateLabelText + author.prefix(clipLength) + "…"
                } else {
                    dateLabelText = dateLabelText + author
                }
            }
        }

        if let feed = CDFeed.feed(id: feedId) {
            if let title = feed.title {
                if let author = author, author.count > 0 {
                    if title != author {
                        dateLabelText = dateLabelText + " | "
                    }
                }
                dateLabelText = dateLabelText + title
            }
        }
        return dateLabelText
    }

    dynamic var favIcon: FavImage? {
//        var result = Image("All Articles")
        if let feed = CDFeed.feed(id: feedId) {
            return FavImage(feed: feed, isFolder: false, isStarred: false)
//            var options: KingfisherOptionsInfo? = nil
//            if !unread {
//                let processor = CompositingImageProcessor(compositingOperation: .copy, alpha: 0.5, backgroundColor: nil)
//                options = [.processor(processor)]
//            }
//            let resource = ImageResource(downloadURL: url, cacheKey: nil)
//            KingfisherManager.shared.retrieveImage(with: resource, options: options, progressBlock: nil, downloadTaskUpdated: nil) { (networkResult) in
//                switch networkResult {
//                case .success(let image):
//                    result = Image(uiImage: image.image)
//                case .failure( _):
//                    break
//                }
//            }
        }
        return nil
    }

    dynamic var starIcon: Image? {
        if starred {
            return Image("starred_mac")
        }
        return Image("unstarred_mac")
    }

    dynamic var labelTextColor: Color {
        var result: Color = .gray
        if !unread {
            result = .gray
        }
        return result
    }

    @objc override public class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
//        print("Debug: called for:", key)

        switch key {
        case "dateAuthorFeed" :
            return Set(["pubDate", "author", "feedId"])
        case "favIcon" :
            return Set(["feedId", "unread"])
        case "starIcon" :
            return Set(["starred"])
        case "thumbnail" :
            return Set(["body"])
        case "thumbnailURL" :
            return Set(["body"])
        case "labelTextColor" :
            return Set(["unread"])
        default :
            return super.keyPathsForValuesAffectingValue(forKey: key)
        }
    }

    static func unreadCount(nodeType: NodeType) -> Int {
        var result = 0
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        switch nodeType {
        case .all:
            let predicate = NSPredicate(format: "unread == true")
            request.predicate = predicate

        case .starred:
            let predicate = NSPredicate(format: "starred == true")
            request.predicate = predicate

        case .feed(let feedId):
            let predicate1 = NSPredicate(format: "unread == true")
            let predicate2 = NSPredicate(format: "feedId == %d", feedId)
            request.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])

        case .folder(let folderId):
            if let feedIds = CDFeed.idsInFolder(folder: folderId) {
                let predicate1 = NSPredicate(format: "unread == true")
                let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
                request.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
            }
        }
        if let count = try? NewsData.mainThreadContext.count(for: request) {
            result = count
        }

        return result
    }

    static func items(itemIds: [Int32]) -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]
        let predicate = NSPredicate(format:"id IN %@", itemIds)
        request.predicate = predicate

        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func items(nodeType: NodeType, hideRead: Bool = false, oldestFirst: Bool = false) -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "lastModified", ascending: oldestFirst)
        request.sortDescriptors = [sortDescription]
        switch nodeType {
        case .all:
            let predicate = NSPredicate(format: "unread == %@", NSNumber(value: hideRead))
            request.predicate = predicate

        case .starred:
            let predicate = NSPredicate(format: "starred == true")
            request.predicate = predicate

        case .feed(let feedId):
            let predicate1 = NSPredicate(format: "unread == %@", NSNumber(value: hideRead))
            let predicate2 = NSPredicate(format: "feedId == %d", feedId)
            request.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])

        case .folder(let folderId):
            if let feedIds = CDFeed.idsInFolder(folder: folderId) {
                let predicate1 = NSPredicate(format: "unread == %@", NSNumber(value: hideRead))
                let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
                request.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
            }
        }
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func markRead(items: [CDItem], unread: Bool) async throws {
        try await NewsData.mainThreadContext.perform {
            do {
                let request = NSBatchUpdateRequest(entityName: CDItem.entityName)
                let itemIds = items.map( { $0.id })
                request.predicate = NSPredicate(format: "id IN %@", itemIds)
                request.propertiesToUpdate = ["unread": NSNumber(value: unread)]
//                request.resultType = .updatedObjectsCountResultType
                try NewsData.mainThreadContext.executeAndMergeChanges(using: request)
                try NewsData.mainThreadContext.save()
            } catch {
                throw PBHError.databaseError("Error marking items read")
            }
        }
    }

    static func markRead(item: CDItem, unread: Bool) async throws {
        try await NewsData.mainThreadContext.perform {
            do {
                item.unread = unread
                try NewsData.mainThreadContext.save()
            } catch {
                throw PBHError.databaseError("Error marking items read")
            }
        }
    }

    static func markStarred(itemId: Int32, state: Bool) async throws {
        try await NewsData.mainThreadContext.perform {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                let predicate = NSPredicate(format:"id == %d", itemId)
                request.predicate = predicate
                let records = try NewsData.mainThreadContext.fetch(request)
                records.forEach({ (item) in
                    item.starred = state
                })
                try NewsData.mainThreadContext.save()
            } catch {
                throw PBHError.databaseError("Error marking item starred")
            }
        }
    }

    static func update(items: [ItemProtocol]) async throws {
        try await NewsData.mainThreadContext.perform {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                for item in items {
                    let predicate = NSPredicate(format: "id == %d", item.id)
                    request.predicate = predicate
                    let records = try NewsData.mainThreadContext.fetch(request)
                    if let existingRecord = records.first {
                        existingRecord.author = item.author
                        existingRecord.body = item.body
                        existingRecord.enclosureLink = item.enclosureLink
                        existingRecord.enclosureMime = item.enclosureMime
                        existingRecord.feedId = item.feedId
                        existingRecord.fingerprint = item.fingerprint
                        existingRecord.guid = item.guid
                        existingRecord.guidHash = item.guidHash
//                        existingRecord.id = item.id
                        existingRecord.lastModified = item.lastModified
                        existingRecord.pubDate = item.pubDate
                        existingRecord.starred = item.starred
                        existingRecord.title = item.title
                        existingRecord.unread = item.unread
                        existingRecord.url = item.url
//                        let _ = existingRecord.thumbnail
                    } else {
                        let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDItem.entityName, into: NewsData.mainThreadContext) as! CDItem
                        newRecord.author = item.author
                        newRecord.body = item.body
                        newRecord.enclosureLink = item.enclosureLink
                        newRecord.enclosureMime = item.enclosureMime
                        newRecord.feedId = item.feedId
                        newRecord.fingerprint = item.fingerprint
                        newRecord.guid = item.guid
                        newRecord.guidHash = item.guidHash
                        newRecord.id = item.id
                        newRecord.lastModified = item.lastModified
                        newRecord.pubDate = item.pubDate
                        newRecord.starred = item.starred
                        newRecord.title = item.title
                        newRecord.unread = item.unread
                        newRecord.url = item.url
                        newRecord.imageLink = ArticleImage.imageURL(urlString: newRecord.url, summary: newRecord.body)
                    }
                }
                try NewsData.mainThreadContext.save()
            } catch {
                throw PBHError.databaseError("Error updating items")
            }
        }
    }

    static func lastModified() -> Int32 {
        var result: Int32 = 0
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "lastModified", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        request.fetchLimit = 1
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            result = Int32(results.first?.lastModified ?? Int32(0))
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return result
    }

}
