//
//  NewsManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018-2022 Peter Hedlund. All rights reserved.
//

import Foundation
import SwiftData

struct ProductStatus {
    var name: String
    var version: String
}

struct SyncTimes {
    let previous: TimeInterval
    let current: TimeInterval
}

extension FeedModel {

    @MainActor
    func version() async throws -> String {
        let router = Router.version
        do {
            let (data, _) = try await session.data(for: router.urlRequest(), delegate: nil)
            let decoder = JSONDecoder()
            let result = try decoder.decode(Status.self, from: data)
            return result.version ?? ""
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func addFeed(url: String, folderId: Int) async throws {
        let router = Router.addFeed(url: url, folder: folderId)
        do {
            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    //                    try await feedImporter.importFeeds(from: data)
                    //                    if let newFeed = modelContext.insertedModelsArray.first as? Feed {
                    //                        let parameters: ParameterDict = ["batchSize": 200,
                    //                                                         "offset": 0,
                    //                                                         "type": 0,
                    //                                                         "id": newFeed.id,
                    //                                                         "getRead": NSNumber(value: true)]
                    //                        let router = Router.items(parameters: parameters)
                    //                        try await itemImporter.fetchItems(router.urlRequest())
                    //                    }
                    try await backgroundModelActor.save()
                case 405:
                    throw NetworkError.methodNotAllowed
                case 409:
                    throw NetworkError.feedAlreadyExists
                case 422:
                    throw NetworkError.feedCouldNotBeRead
                default:
                    throw NetworkError.feedErrorAdding
                }
            }
        } catch(let error as NetworkError) {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func addFolder(name: String) async throws {
        let router = Router.addFolder(name: name)
        do {
            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    break
                    //                   TODO try await folderImporter.importFolders(from: data)
                case 405:
                    throw NetworkError.methodNotAllowed
                case 409:
                    throw NetworkError.folderAlreadyExists
                case 422:
                    throw NetworkError.folderNameInvalid
                default:
                    throw NetworkError.folderErrorAdding
                }
            }
        } catch(let error as NetworkError) {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func markRead(items: [Item], unread: Bool) async throws {
        guard !items.isEmpty else {
            return
        }
        do {
            let itemIds = items.map( { $0.id } )
            let parameters: ParameterDict = ["items": itemIds]
            var router: Router
            if unread {
                router = Router.itemsUnread(parameters: parameters)
            } else {
                router = Router.itemsRead(parameters: parameters)
            }
            let (_, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if unread {
                        try await backgroundModelActor.delete(Unread.self)
                        try await backgroundModelActor.save()
                    } else {
                        try await backgroundModelActor.delete(Read.self)
                        try await backgroundModelActor.save()
                    }
                default:
                    if unread {
                        for itemId in itemIds {
                            await backgroundModelActor.insert(Read(itemId: itemId))
                        }
                        try await backgroundModelActor.save()
                    } else {
                        for itemId in itemIds {
                            await backgroundModelActor.insert(Unread(itemId: itemId))
                        }
                        try await backgroundModelActor.save()
                    }
                }
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func markStarred(item: Item, starred: Bool) async throws {
        do {
            item.starred = starred
            try await backgroundModelActor.save()

            let parameters: ParameterDict = ["items": [["feedId": item.feedId,
                                                        "guidHash": item.guidHash as Any]]]
            var router: Router
            if starred {
                router = Router.itemsStarred(parameters: parameters)
            } else {
                router = Router.itemsUnstarred(parameters: parameters)
            }
            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    if starred {
                        try await backgroundModelActor.delete(Unstarred.self)
                    } else {
                        try await backgroundModelActor.delete(Starred.self)
                    }
                default:
                    if starred {
                        await backgroundModelActor.insert(Starred(itemId: item.id))
                    } else {
                        await backgroundModelActor.insert(Unstarred(itemId: item.id))
                    }
                }
                try await backgroundModelActor.save()
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    /*
     Initial sync

     1. unread articles: GET /items?type=3&getRead=false&batchSize=-1
     2. starred articles: GET /items?type=2&getRead=true&batchSize=-1
     3. folders: GET /folders
     4. feeds: GET /feeds
     */

    func initialSync() async throws {
        let unreadParameters: ParameterDict = ["type": 3,
                                               "getRead": false,
                                               "batchSize": -1]
        let unreadRouter = Router.items(parameters: unreadParameters)

        let starredParameters: ParameterDict = ["type": 2,
                                                "getRead": true,
                                                "batchSize": -1]
        let starredRouter = Router.items(parameters: starredParameters)

        do {
            try await webImporter.updateFoldersInDatabase(urlRequest: Router.folders.urlRequest())
            try await webImporter.updateFeedsInDatabase(urlRequest: Router.feeds.urlRequest())
            try await webImporter.updateItemsInDatabase(urlRequest: unreadRouter.urlRequest())
            try await webImporter.updateItemsInDatabase(urlRequest: starredRouter.urlRequest())
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    /*
     Syncing

     When syncing, you want to push read/unread and starred/unstarred items to the server and receive new and updated items, feeds and folders. To do that, call the following routes:

     1. Notify the News app of unread articles: PUT /items/unread/multiple {"items": [1, 3, 5] }
     2. Notify the News app of read articles: PUT /items/read/multiple {"items": [1, 3, 5]}
     3. Notify the News app of starred articles: PUT /items/starred/multiple {"items": [{"feedId": 3, "guidHash": "adadafasdasd1231"}, ...]}
     4. Notify the News app of unstarred articles: PUT /items/unstarred/multiple {"items": [{"feedId": 3, "guidHash": "adadafasdasd1231"}, ...]}
     5. Get new folders: GET /folders
     6. Get new feeds: GET /feeds
     7. Get new items and modified items: GET /items/updated?lastModified=12123123123&type=3

     */

    func sync() async throws {
        //        CDFeeds.reset()
        //        CDFeed.reset()
        //        CDFolder.reset()
        //        CDItem.reset()
        //
        isSyncing = true
        do {
            //            let itemCount = try await backgroundModelActor.fetchCount()
            //            if itemCount == 0 {
            //                try await self.initialSync()
            //                return
            //            }
            //        } catch { }

            //        do {
            //            Task {
            //                let localRead: [Read] = try await backgroundModelActor.fetchData()
            //                if !localRead.isEmpty {
            //                    let localReadIds = localRead.map( { $0.itemId } )
            //                    let readParameters = ["items": localReadIds]
            //                    let readRouter = Router.itemsRead(parameters: readParameters)
            //                    async let (_, readResponse) = session.data(for: readRouter.urlRequest(), delegate: nil)
            //                    let readItemsResponse = try await readResponse
            //                    if let httpReadResponse = readItemsResponse as? HTTPURLResponse {
            //                        switch httpReadResponse.statusCode {
            //                        case 200:
            //                            try await backgroundModelActor.delete(Read.self)
            //                        default:
            //                            break
            //                        }
            //                    }
            //                }
            //
            //                let localStarred: [Starred] = try await backgroundModelActor.fetchData()
            //                if !localStarred.isEmpty {
            //                    let localStarredIds = localStarred.map( { $0.itemId } )
            //                    let starredItemsFetchDescriptor = FetchDescriptor<Item>(predicate: #Predicate {
            //                        localStarredIds.contains($0.id)
            //                    })
            //                    let predicate = #Predicate<Item> {
            //                        localStarredIds.contains($0.id)
            //                    }
            //                    let starredItems: [Item] = try await backgroundModelActor.fetchData(predicate: predicate)
            //                    if !starredItems.isEmpty {
            //                        var params = [Any]()
            //                        for starredItem in starredItems {
            //                            var param: [String: Any] = [:]
            //                            param["feedId"] = starredItem.feedId
            //                            param["guidHash"] = starredItem.guidHash
            //                            params.append(param)
            //                        }
            //                        let starredParameters = ["items": params]
            //                        let starredRouter = Router.itemsStarred(parameters: starredParameters)
            //                        async let (_, starredResponse) = session.data(for: starredRouter.urlRequest(), delegate: nil)
            //                        let starredItemsResponse = try await starredResponse
            //                        if let httpStarredResponse = starredItemsResponse as? HTTPURLResponse {
            //                            switch httpStarredResponse.statusCode {
            //                            case 200:
            //                                try await backgroundModelActor.delete(Starred.self)
            //                            default:
            //                                break
            //                            }
            //                        }
            //                    }
            //                }
            //
            //                let localUnstarred: [Unstarred] = try await backgroundModelActor.fetchData()
            //                if !localUnstarred.isEmpty {
            //                    let localUnstarredIds = localUnstarred.map( { $0.itemId } )
            //                    let predicate = #Predicate<Item> {
            //                        localUnstarredIds.contains($0.id)
            //                    }
            //                    let unstarredItems: [Item] = try await backgroundModelActor.fetchData(predicate: predicate)
            //                    if !unstarredItems.isEmpty {
            //                        var params: [Any] = []
            //                        for unstarredItem in unstarredItems {
            //                            var param: [String: Any] = [:]
            //                            param["feedId"] = unstarredItem.feedId
            //                            param["guidHash"] = unstarredItem.guidHash
            //                            params.append(param)
            //                        }
            //                        let unStarredParameters = ["items": params]
            //                        let unStarredRouter = Router.itemsUnstarred(parameters: unStarredParameters)
            //                        async let (_, unStarredResponse) = session.data(for: unStarredRouter.urlRequest(), delegate: nil)
            //                        let unStarredItemsResponse = try await unStarredResponse
            //                        if let httpUnStarredResponse = unStarredItemsResponse as? HTTPURLResponse {
            //                            switch httpUnStarredResponse.statusCode {
            //                            case 200:
            //                                try await backgroundModelActor.delete(Unstarred.self)
            //                            default:
            //                                break
            //                            }
            //                        }
            //                    }
            //                }
            //            }

            let newestKnownLastModified = await backgroundModelActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            try await itemPruner.pruneItems(daysOld: Preferences().keepDuration)
            try await webImporter.updateFoldersInDatabase(urlRequest: Router.folders.urlRequest())
            print("Done with folders")
            try await webImporter.updateFeedsInDatabase(urlRequest: Router.feeds.urlRequest())
            print("Done with feeds")
            try await webImporter.updateItemsInDatabase(urlRequest: updatedItemRouter.urlRequest())
            print("Done with items")
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func moveFeed(feed: Feed, to folder: Int64) async throws {
        let moveFeedRouter = Router.moveFeed(id: Int(feed.id), folder: Int(folder))
        do {
            let (_, moveResponse) = try await session.data(for: moveFeedRouter.urlRequest(), delegate: nil)
            if let httpResponse = moveResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw NetworkError.feedDoesNotExist
                default:
                    throw NetworkError.feedErrorMoving
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func renameFeed(feed: Feed, to name: String) async throws {
        let renameRouter = Router.renameFeed(id: Int(feed.id), newName: name)
        do {
            let (_, renameResponse) = try await session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw NetworkError.feedDoesNotExist
                case 405:
                    throw NetworkError.newsAppNeedsUpdate
                default:
                    throw NetworkError.feedErrorRenaming
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func deleteFeed(_ id: Int) async throws {
        let deleteRouter = Router.deleteFeed(id: id)
        do {
            let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    try await backgroundModelActor.deleteItems(with: Int64(id))
                    try await backgroundModelActor.deleteFeed(id: Int64(id))
                    throw NetworkError.feedDoesNotExist
                default:
                    throw NetworkError.feedErrorDeleting
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
    func renameFolder(folder: Folder, to name: String) async throws {
        let renameRouter = Router.renameFolder(id: Int(folder.id), newName: name)
        do {
            let (_, renameResponse) = try await session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw NetworkError.folderDoesNotExist
                case 409:
                    throw NetworkError.folderAlreadyExists
                case 422:
                    throw NetworkError.folderNameInvalid
                default:
                    throw NetworkError.folderErrorRenaming
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func deleteFolder(_ id: Int) async throws {
        let deleteRouter = Router.deleteFolder(id: id)
        do {
            let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw NetworkError.folderDoesNotExist
                default:
                    throw NetworkError.folderErrorDeleting
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

}
