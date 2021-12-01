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
        let (folderData, _ /*folderResponse*/) = try await NewsManager.session.data(for: Router.folders.urlRequest(), delegate: nil)
        let folders: Folders = try getType(from: folderData)
        if let folders = folders.folders {
            try await CDFolder.add(folders: folders, using: importContext)
        }
        try importContext.save()
    }
}

class FeedImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
      importContext = persistentContainer.newBackgroundContext()
      importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func performImport() async throws {
        let (feedsData, _ /*feedsResponse*/) = try await NewsManager.session.data(for: Router.feeds.urlRequest(), delegate: nil)
        let feeds: Feeds = try getType(from: feedsData)
        if let feeds = feeds.feeds {
            try await CDFeed.add(feeds: feeds, using: importContext)
        }
        try importContext.save()
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
        let (updatedItemsData, _ /*feedsResponse*/) = try await NewsManager.session.data(for: updatedItemRouter.urlRequest(), delegate: nil)
        let items: Items = try getType(from: updatedItemsData)

        if let items = items.items {
            try await CDItem.add(items: items, using: importContext)
        }
        try importContext.save()
    }
}
