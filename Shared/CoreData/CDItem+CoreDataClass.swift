//
//  CDItem+CoreDataClass.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import CoreData

@objc(CDItem)
public class CDItem: NSManagedObject, ItemProtocol {

    static let entityName = "CDItem"

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

        if !dateLabelText.isEmpty {
            dateLabelText.append(" | ")
        }

        if let author = author, !author.isEmpty {
            let clipLength = 50
            if author.count > clipLength {
                dateLabelText.append(contentsOf: author.replacingOccurrences(of: "\n", with: "").prefix(clipLength))
                dateLabelText.append("…")
            } else {
                dateLabelText.append(author)
            }
        }

        if let feed = CDFeed.feed(id: feedId) {
            if let title = feed.title {
                if let author = author, !author.isEmpty {
                    if title != author {
                        dateLabelText.append(" | \(title)")
                    }
                } else {
                    dateLabelText.append(title)
                }
            }
        }
        return dateLabelText
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

    static func starredItems() -> [CDItem]? {
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        let predicate = NSPredicate(format: "starred == true")
        request.predicate = predicate
        do {
            return try NewsData.mainThreadContext.fetch(request)
        } catch {
            return nil
        }
    }

    static func items(lastModified: Int32) -> [CDItem]? {
        let request: NSFetchRequest<CDItem> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]
        let predicate = NSPredicate(format:"lastModified > %d", lastModified)
        request.predicate = predicate

        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func itemsWithoutImageLink() -> [CDItem]? {
        let request: NSFetchRequest<CDItem> = self.fetchRequest()
        let predicate = NSPredicate(format: "imageLink == nil")
        request.predicate = predicate
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
                for item in items {
                    item.unread = unread
                }
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

    static func add(items: [ItemProtocol], using context: NSManagedObjectContext) async throws {
        await context.perform {
            let itemCount = items.count
            var current = 0
            for item in items {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDItem.entityName, into: context) as! CDItem
                newRecord.author = item.author
                newRecord.body = item.body
                newRecord.displayBody = itemDisplayBody(item.body, mediaDescription: nil)
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
                newRecord.title = itemDisplayTitle(item.title)
                newRecord.unread = item.unread
                newRecord.url = item.url
                current += 1
                print("Count \(itemCount), Current \(current)")
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

    static func addImageLink(item: CDItem, imageLink: String) async throws {
        try await NewsData.mainThreadContext.perform {
            do {
                let currentData = item.imageLink
                if imageLink == currentData {
                    print("Same image link")
                } else {
                    item.imageLink = imageLink
                    try NewsData.mainThreadContext.save()
                }
            } catch {
                throw PBHError.databaseError("Error adding imageLink")
            }
        }
    }

    @discardableResult
    static func deleteOldItems() async throws -> NSBatchDeleteResult? {
        try await NewsData.mainThreadContext.perform {
            let keepDuration = Preferences().keepDuration
            if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * keepDuration), to: Date())?.timeIntervalSince1970 {
                let predicate1 = NSPredicate(format: "unread == false")
                let predicate2 = NSPredicate(format: "starred == false")
                let predicate3 = NSPredicate(format:"lastModified < %d", Int32(limitDate))
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2, predicate3])

                let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
                request.predicate = predicate
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                do {
                    let result = try NewsData.mainThreadContext.execute(batchDeleteRequest)
                    try NewsData.mainThreadContext.save()
                    NewsData.mainThreadContext.reset()
                    return result as? NSBatchDeleteResult
                } catch let error as NSError {
                    print("Could not perform deletion \(error), \(error.userInfo)")
                    throw PBHError.databaseError("Error deleting old items")
                }
            }
            return nil
        }
    }

    @discardableResult
    static func deleteItems(with feedId: Int32) async throws -> NSBatchDeleteResult? {
        var result: NSPersistentStoreResult?
        try await NewsData.mainThreadContext.perform {
            let predicate = NSPredicate(format: "feedId == %d", feedId)
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
            request.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            do {
                result = try NewsData.mainThreadContext.execute(batchDeleteRequest)
                try NewsData.mainThreadContext.save()
                NewsData.mainThreadContext.reset()
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
                throw PBHError.databaseError("Error deleting items in feed \(feedId)")
            }
        }
        return result as? NSBatchDeleteResult
    }

    static func reset() {
        NewsData.mainThreadContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            do {
                try NewsData.mainThreadContext.executeAndMergeChanges(using: deleteRequest)
            } catch {
                let updateError = error as NSError
                print("\(updateError), \(updateError.userInfo)")
            }
        }
    }
    
}
