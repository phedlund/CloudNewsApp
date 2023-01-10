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

@objc(CDItem)
public class CDItem: NSManagedObject, ItemProtocol {

    static let entityName = "CDItem"

    var webViewHelper = ItemWebViewHelper()

    static func unreadCount(nodeType: NodeType) -> Int {
        var result = 0
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        switch nodeType {
        case .empty:
            break
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
        if let count = try? NewsData.shared.container.viewContext.count(for: request) {
            result = count
        }

        return result
    }

    static func unreadItems(nodeType: NodeType) -> [CDItem] {
        var result = [CDItem]()
        let request : NSFetchRequest<CDItem> = self.fetchRequest()
        switch nodeType {
        case .empty:
            break
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
        if let items = try? NewsData.shared.container.viewContext.fetch(request) {
            result = items
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
            let results  = try NewsData.shared.container.viewContext.fetch(request)
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
            return try NewsData.shared.container.viewContext.fetch(request)
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
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            return results
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func markRead(items: [CDItem], unread: Bool) async throws {
        try await NewsData.shared.container.viewContext.perform {
            do {
                for item in items {
                    item.unread = unread
                }
//                try NewsData.shared.container.viewContext.save()
            } catch {
                throw PBHError.databaseError(message: "Error marking items read")
            }
        }
    }

    static func markRead(item: CDItem, unread: Bool) async throws {
        try await NewsData.shared.container.viewContext.perform {
            do {
                item.unread = unread
//                try NewsData.shared.container.viewContext.save()
            } catch {
                throw PBHError.databaseError(message: "Error marking items read")
            }
        }
    }

    static func markStarred(itemId: Int32, state: Bool) async throws {
        try await NewsData.shared.container.viewContext.perform {
            let request: NSFetchRequest<CDItem> = CDItem.fetchRequest()
            do {
                let predicate = NSPredicate(format:"id == %d", itemId)
                request.predicate = predicate
                let records = try NewsData.shared.container.viewContext.fetch(request)
                records.forEach({ (item) in
                    item.starred = state
                })
                try NewsData.shared.container.viewContext.save()
            } catch {
                throw PBHError.databaseError(message: "Error marking item starred")
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
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            result = Int32(results.first?.lastModified ?? Int32(0))
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return result
    }

    static func addImageLink(item: CDItem, imageLink: String) async throws {
        try await NewsData.shared.container.viewContext.perform {
            do {
                let currentData = item.imageLink
                if imageLink == currentData {
                    print("Same image link \(imageLink)")
                } else {
                    item.imageLink = imageLink
                    if !imageLink.isEmpty, imageLink != "data:null", let url = URL(string: imageLink) {
                        item.imageUrl = url as NSURL
                    }
//                    try NewsData.shared.container.viewContext.save()
                }
            } catch {
                throw PBHError.databaseError(message: "Error adding imageLink")
            }
        }
    }

    @discardableResult
    static func deleteItems(with feedId: Int32) async throws -> NSBatchDeleteResult? {
        var result: NSPersistentStoreResult?
        try await NewsData.shared.container.viewContext.perform {
            let predicate = NSPredicate(format: "feedId == %d", feedId)
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
            request.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            do {
                result = try NewsData.shared.container.viewContext.execute(batchDeleteRequest)
//                try NewsData.shared.container.viewContext.save()
                NewsData.shared.container.viewContext.reset()
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
                throw PBHError.databaseError(message: "Error deleting items in feed \(feedId)")
            }
        }
        return result as? NSBatchDeleteResult
    }

    static func reset() {
        NewsData.shared.container.viewContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            do {
                try NewsData.shared.container.viewContext.executeAndMergeChanges(using: deleteRequest)
            } catch {
                let updateError = error as NSError
                print("\(updateError), \(updateError.userInfo)")
            }
        }
    }
    
}
