//
//  ModelContextExtension.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/8/24.
//

import Foundation
import SwiftData

extension ModelContext {

    func allFolders() -> [Folder]? {
        let sortDescriptor = SortDescriptor<Folder>(\.id, order: .forward)
        let descriptor = FetchDescriptor<Folder>(sortBy: [sortDescriptor])
        do {
            return try fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func folder(id: Int64) -> Folder? {
        let predicate = #Predicate<Folder>{ $0.id == id }

        var descriptor = FetchDescriptor<Folder>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func folder(name: String) -> Folder? {
        let predicate = #Predicate<Folder>{ $0.name == name }
        var descriptor = FetchDescriptor<Folder>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func deleteFolder(id: Int64) async throws {
        do {
            try delete(model: Folder.self, where: #Predicate { $0.id == id } )
            try save()
        } catch {
            //                self.logger.debug("Failed to execute items insert request.")
            throw DatabaseError.folderErrorDeleting
        }
    }

    func folderNodeModel(nodeName: String) -> Node? {
        let predicate = #Predicate<Node>{ $0.nodeName == nodeName }
        var descriptor = FetchDescriptor<Node>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func allFeeds() -> [Feed]? {
        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        //        let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned)
        let descriptor = FetchDescriptor<Feed>(sortBy: [idSortDescriptor])
        do {
            return try fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feed(id: Int64) -> Feed? {
        let predicate = #Predicate<Feed>{ $0.id == id }

        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feedsInFolder(folder: Int64) -> [Feed]? {
        let predicate = #Predicate<Feed>{ $0.folderId == folder }

        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        //let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned, order: .forward)
        let descriptor = FetchDescriptor<Feed>(predicate: predicate, sortBy: [idSortDescriptor])
        do {
            return try fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feedIdsInFolder(folder: Int64) -> [Int64]? {
        if let feeds = feedsInFolder(folder: folder) {
            return feeds.map { $0.id }
        }
        return nil
    }

    func deleteFeed(id: Int64) async throws {
        do {
            try delete(model: Feed.self, where: #Predicate { $0.id == id } )
            try save()
        } catch {
            //                self.logger.debug("Failed to execute items insert request.")
            throw DatabaseError.feedErrorDeleting
        }
    }

    func deleteItems(with feedId: Int64) async throws {
        do {
            try delete(model: Item.self, where: #Predicate { $0.feedId == feedId } )
            try save()
        } catch {
            //                self.logger.debug("Failed to execute items insert request.")
            throw DatabaseError.itemErrorDeleting
        }
    }
}
