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
      importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let foldersDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let folderDicts = foldersDict["folders"] as? [[String: Any]],
                          !folderDicts.isEmpty else {
                        return
                    }
                    let request = NSBatchInsertRequest(entityName: CDFolder.entityName, objects: folderDicts)
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Folders imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting folders")
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
        importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let feedsDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let feedDicts = feedsDict["feeds"] as? [[String: Any]],
                          !feedDicts.isEmpty else {
                        return
                    }
                    let request = NSBatchInsertRequest(entityName: CDFeed.entityName, objects: feedDicts)
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Feeds imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting feeds")
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
        importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let itemsDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let itemDicts = itemsDict["items"] as? [[String: Any]],
                          !itemDicts.isEmpty else {
                        return
                    }
                    let request = NSBatchInsertRequest(entityName: CDItem.entityName, objects: itemDicts)
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Items imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting items")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}
