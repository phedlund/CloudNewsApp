//
//  ItemImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/21.
//

import CoreData
import Foundation

class FolderImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
      importContext = persistentContainer.newBackgroundContext()
      importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func performImport() async throws {
        do {
            let (folderData, _ /*folderResponse*/) = try await NewsManager.session.data(for: Router.folders.urlRequest(), delegate: nil)
            let folders: Folders = try getType(from: folderData)
            if let folderDicts = folders.foldersAsDictionaries() {
                let request = NSBatchInsertRequest(entityName: CDFolder.entityName, objects: folderDicts)
                request.resultType = NSBatchInsertRequestResultType.count
                let result = try importContext.execute(request) as? NSBatchInsertResult
                print("Folders imported \(result?.result ?? -1)")
                try importContext.save()
            }
        } catch { }
    }
}

class FeedImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
      importContext = persistentContainer.newBackgroundContext()
      importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func performImport() async throws {
        do {
            let (feedsData, _ /*feedsResponse*/) = try await NewsManager.session.data(for: Router.feeds.urlRequest(), delegate: nil)
            let feeds: Feeds = try getType(from: feedsData)
            if let feedDicts = feeds.feedsAsDictionaries() {
                let request = NSBatchInsertRequest(entityName: CDFeed.entityName, objects: feedDicts)
                request.resultType = NSBatchInsertRequestResultType.count
                let result = try importContext.execute(request) as? NSBatchInsertResult
                print("Feeds imported \(result?.result ?? -1)")
                try importContext.save()
            }
        } catch { }
    }
}

class ItemImporter {
    let importContext: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentContainer) {
        importContext = persistentContainer.newBackgroundContext()
        importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func performImport() async throws {
        let newestKnownLastModified = CDItem.lastModified()
        Preferences().lastModified = newestKnownLastModified
        
        let updatedParameters: ParameterDict = ["type": 3,
                                                "lastModified": newestKnownLastModified,
                                                "id": 0]
        let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)
        do {
            let (updatedItemsData, _ /*feedsResponse*/) = try await NewsManager.session.data(for: updatedItemRouter.urlRequest(), delegate: nil)
            let items: Items = try getType(from: updatedItemsData)
            if let itemDicts = items.itemsAsDictionaries() {
                let request = NSBatchInsertRequest(entityName: CDItem.entityName, objects: itemDicts)
                request.resultType = NSBatchInsertRequestResultType.count
                let result = try importContext.execute(request) as? NSBatchInsertResult
                print("Items imported \(result?.result ?? -1)")
                try importContext.save()
            }
        } catch { }
    }
}
