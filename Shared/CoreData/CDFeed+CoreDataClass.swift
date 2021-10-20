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

    static private let entityName = "CDFeed"
    
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
    
    static func update(feeds: [FeedProtocol]) {
        NewsData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDFeed> = CDFeed.fetchRequest()
            do {
                for feed in feeds {
                    let predicate = NSPredicate(format: "id == %d", feed.id)
                    request.predicate = predicate
                    let records = try NewsData.mainThreadContext.fetch(request)
                    if let existingRecord = records.first {
                        existingRecord.added = Int32(feed.added)
                        existingRecord.faviconLink = feed.faviconLink
                        existingRecord.folderId = Int32(feed.folderId)
//                        existingRecord.id = Int32(feed.id)
                        existingRecord.lastUpdateError = feed.lastUpdateError
                        existingRecord.link = feed.link
                        existingRecord.ordering = Int32(feed.ordering)
                        existingRecord.pinned = feed.pinned
                        existingRecord.title = feed.title
                        existingRecord.unreadCount = Int32(feed.unreadCount)
                        existingRecord.updateErrorCount = Int32(feed.updateErrorCount)
                        existingRecord.url = feed.url
                    } else {
                        let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDFeed.entityName, into: NewsData.mainThreadContext) as! CDFeed
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
                try NewsData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }

}
