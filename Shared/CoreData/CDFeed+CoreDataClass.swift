//
//  CDFeed+CoreDataClass.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import Foundation
import CoreData

@objc(CDFeed)
public class CDFeed: NSManagedObject, FeedProtocol, Identifiable {

    static let entityName = "CDFeed"
    
    static func all() -> [CDFeed]? {
        let request: NSFetchRequest<CDFeed> = self.fetchRequest()
        let pinnedSortDescriptor = NSSortDescriptor(key: "pinned", ascending: false)
        let idSortDescriptor = NSSortDescriptor(key: "id", ascending: true)
        request.sortDescriptors = [pinnedSortDescriptor, idSortDescriptor]

        var feedList = [CDFeed]()
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            for record in results {
                feedList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return feedList
    }

    static func feed(id: Int32) -> CDFeed? {
        let request: NSFetchRequest<CDFeed> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func inFolder(folder: Int32) -> [CDFeed]? {
        let request: NSFetchRequest<CDFeed> = self.fetchRequest()
        let predicate = NSPredicate(format: "folderId == %d", folder)
        request.predicate = predicate
        let idSortDescriptor = NSSortDescriptor(key: "id", ascending: false)
        let pinnedSortDescriptor = NSSortDescriptor(key: "pinned", ascending: false)
        request.sortDescriptors = [pinnedSortDescriptor, idSortDescriptor]

        var feedList = [CDFeed]()
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            for record in results {
                feedList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return feedList
    }

    static func idsInFolder(folder: Int32) -> [Int32]? {
        if let feeds = CDFeed.inFolder(folder: folder) {
            return feeds.map { $0.id }
        }
        return nil
    }

    static func add(feeds: [FeedProtocol], using context: NSManagedObjectContext) async throws {
        await context.perform {
            for feed in feeds {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDFeed.entityName, into: context) as! CDFeed
                newRecord.added = Int32(feed.added)
                newRecord.faviconLink = feed.faviconLink
                newRecord.folderId = Int32(feed.folderId)
                newRecord.id = Int32(feed.id)
                newRecord.lastUpdateError = feed.lastUpdateError
                newRecord.link = feed.link
                newRecord.ordering = Int32(feed.ordering)
                newRecord.pinned = feed.pinned
                newRecord.title = feed.title
                newRecord.unreadCount = Int32(feed.unreadCount)
                newRecord.updateErrorCount = Int32(feed.updateErrorCount)
                newRecord.url = feed.url
            }
        }
    }

    static func addFavIconLinkResolved(feed: CDFeed, link: String) async throws {
        try await NewsData.mainThreadContext.perform {
            do {
                feed.faviconLinkResolved = link
                try NewsData.mainThreadContext.save()
            } catch {
                throw PBHError.databaseError(message: "Error adding favicon")
            }
        }
    }

    static func delete(id: Int32) async throws {
        let request: NSFetchRequest<CDFeed> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NewsData.mainThreadContext.fetch(request)
            if let feed = results.first {
                NewsData.mainThreadContext.delete(feed)
            }
            try NewsData.mainThreadContext.save()
        } catch {
            throw PBHError.databaseError(message: "Error deleting feed")
        }
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
