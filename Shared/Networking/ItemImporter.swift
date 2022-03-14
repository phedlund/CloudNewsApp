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

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await NewsManager.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    let folders: Folders = try getType(from: data)
                    if let folderDicts = folders.foldersAsDictionaries() {
                        let request = NSBatchInsertRequest(entityName: CDFolder.entityName, objects: folderDicts)
                        request.resultType = NSBatchInsertRequestResultType.count
                        let result = try importContext.execute(request) as? NSBatchInsertResult
                        print("Folders imported \(result?.result ?? -1)")
                        try importContext.save()
                    }
                default:
                    throw PBHError.networkError("Error getting folders")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}

class FeedImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
      importContext = persistentContainer.newBackgroundContext()
      importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await NewsManager.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    let feeds: Feeds = try getType(from: data)
                    if let feedDicts = feeds.feedsAsDictionaries() {
                        let request = NSBatchInsertRequest(entityName: CDFeed.entityName, objects: feedDicts)
                        request.resultType = NSBatchInsertRequestResultType.count
                        let result = try importContext.execute(request) as? NSBatchInsertResult
                        print("Feeds imported \(result?.result ?? -1)")
                        try importContext.save()
                    }
                default:
                    throw PBHError.networkError("Error getting feeds")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}

class ItemImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
        importContext = persistentContainer.newBackgroundContext()
        importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await NewsManager.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    let items: Items = try getType(from: data)
                    if let itemDicts = items.itemsAsDictionaries() {
                        let request = NSBatchInsertRequest(entityName: CDItem.entityName, objects: itemDicts)
                        request.resultType = NSBatchInsertRequestResultType.count
                        let result = try importContext.execute(request) as? NSBatchInsertResult
                        print("Items imported \(result?.result ?? -1)")
                        try importContext.save()
                    }
                default:
                    throw PBHError.networkError("Error getting items")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}
