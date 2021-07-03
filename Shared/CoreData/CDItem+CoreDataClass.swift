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

    dynamic var favIcon: Image? {
        var result = Image("All Articles")
        if let feed = CDFeed.feed(id: feedId),
            let faviconLink = feed.faviconLink,
            let url = URL(string: faviconLink) {
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
        return result
    }

    dynamic var starIcon: Image? {
        if starred {
            return Image("starred_mac")
        }
        return Image("unstarred_mac")
    }

    dynamic var thumbnailURL: URL? {
        if let summary = body, let imageURL = self.imageURL(summary: summary) {
            return imageURL
        }
        return nil
    }

    dynamic var thumbnail: Image? {
        var result: Image?
        guard let imageURL = self.thumbnailURL else {
            return result
        }

//        let resource = ImageResource(downloadURL: imageURL)
//        KingfisherManager.shared.retrieveImage(with: resource, options: nil, progressBlock: nil, downloadTaskUpdated: nil) { (networkResult) in
//            switch networkResult {
//            case .success(let image):
//                result = Image(uiImage: image.image)
//            case .failure( _):
//                break
//            }
//        }
       return result
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

    static func all() -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]

        var itemList = [CDItem]()
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            for record in results {
                itemList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return itemList
    }

    static func unreadCount(feed: Int32) -> Int {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let predicate = NSPredicate(format: "feedId == %d", feed)
        request.predicate = predicate

        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results.filter( { $0.unread } ).count
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return 0
    }

    static func unreadCount(folder: Int32) -> Int {
        if let feedIds = CDFeed.idsInFolder(folder: folder) {
            let request : NSFetchRequest<CDItem> = self.fetchRequest()
            let predicate = NSPredicate(format: "feedId IN %@", feedIds)
            request.predicate = predicate

            do {
                let results  = try NewsData.mainThreadContext.fetch(request)
                return results.filter( { $0.unread } ).count
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return 0
    }

    static func items(itemIds: [Int32]) -> [ItemProtocol]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]
        let predicate = NSPredicate(format:"id IN %@", itemIds)
        request.predicate = predicate
        
        var itemList = [ItemProtocol]()
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            for record in results {
                itemList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return itemList
    }

    static func items(feed: Int32) -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let predicate = NSPredicate(format: "feedId == %d", feed)
        request.predicate = predicate

        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func starredItems() -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]
        let predicate = NSPredicate(format: "starred == true")
        request.predicate = predicate
        
        var itemList = [CDItem]()
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            for record in results {
                itemList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return itemList
    }
    
    static func markRead(itemIds: [Int32], state: Bool, completion: SyncCompletionBlock) {
        NewsData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                let predicate = NSPredicate(format:"id IN %@", itemIds)
                request.predicate = predicate
                let records = try NewsData.mainThreadContext.fetch(request)
                records.forEach({ (item) in
                    item.unread = state
                })
                try NewsData.mainThreadContext.save()
            } catch { }
            completion()
        }
    }

    static func markStarred(itemId: Int32, state: Bool, completion: SyncCompletionBlock) {
        NewsData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                let predicate = NSPredicate(format:"id == %d", itemId)
                request.predicate = predicate
                let records = try NewsData.mainThreadContext.fetch(request)
                records.forEach({ (item) in
                    item.starred = state
                })
                try NewsData.mainThreadContext.save()
            } catch { }
            completion()
        }
    }

    static func update(items: [ItemProtocol], completion: SyncCompletionBlockNewItems?) {
        NewsData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                var newItemsCount = 0
                var newItems = [ItemProtocol]()
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
                        let _ = existingRecord.thumbnail
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
                        newItems.append(newRecord)
                        newItemsCount += 1
                        let _ = newRecord.thumbnail
                    }
                }
                try NewsData.mainThreadContext.save()
                if let completion = completion, newItemsCount > 0 {
                    completion(newItems)
                }
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
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
    
    static func unreadCount() -> Int {
        var result = 0
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let predicate = NSPredicate(format: "unread == true")
        request.predicate = predicate
        if let count = try? NewsData.mainThreadContext.count(for: request) {
            result = count
        }
        return result
    }

    private func imageURL(summary: String) -> URL? {
        guard let doc: Document = try? SwiftSoup.parse(summary) else {
            return nil
        } // parse html
        do {
            let srcs: Elements = try doc.select("img[src]")
            let srcsStringArray: [String?] = srcs.array().map { try? $0.attr("src").description }
            if let firstString = srcsStringArray.first, let urlString = firstString, let url = URL(string: urlString) {
                return url
            }
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("error")

        }
        return nil
    }

}
