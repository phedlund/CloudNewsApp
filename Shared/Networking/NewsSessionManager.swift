//
//  NewsSessionManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018-2022 Peter Hedlund. All rights reserved.
//

import Combine
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

class NewsManager {

    static let shared = NewsManager()
    private let session = ServerStatus.shared.session
    let syncSubject = PassthroughSubject<SyncTimes, Never>()

    init() { }
    
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

    func addFeed(url: String, folderId: Int) async throws {
        let router = Router.addFeed(url: url, folder: folderId)
        do {
            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    break
//                    TODO if let feeds: Feeds = try getType(from: data),
//                       let feedArray = feeds.feeds,
//                       let newFeed = feedArray.first {
//                        let newFeedId = newFeed.id
//                        try await CDFeed.add(feeds: feedArray, using: NewsData.shared.container.viewContext)
//                        try NewsData.shared.container.viewContext.save()
//                        let parameters: ParameterDict = ["batchSize": 200,
//                                                         "offset": 0,
//                                                         "type": 0,
//                                                         "id": newFeedId,
//                                                         "getRead": NSNumber(value: true)]
//                        let router = Router.items(parameters: parameters)
//                        try await ItemImporter().fetchItems(router.urlRequest())
//                    }
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
//                    TODO if let folders: Folders = try getType(from: data),
//                        let folderArray = folders.folders {
//                        try await CDFolder.add(folders: folderArray, using: NewsData.shared.container.viewContext)
//                        try NewsData.shared.container.viewContext.save()
//                    }
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

    func markRead(items: [Item], unread: Bool) async throws {
        do {
//            try await ItemReadManager.shared.markRead(items: items, unread: unread)
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func markStarred(item: Item, starred: Bool) async throws {
//        TODO do {
//            try await Item.markStarred(itemId: item.id, state: starred)
//            let parameters: ParameterDict = ["items": [["feedId": item.feedId,
//                                                        "guidHash": item.guidHash as Any]]]
//            var router: Router
//            if starred {
//                try await CDStarred.update(items: [item.id])
//                router = Router.itemsStarred(parameters: parameters)
//            } else {
//                try await CDUnstarred.update(items: [item.id])
//                router = Router.itemsUnstarred(parameters: parameters)
//            }
//            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
//            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
//                switch httpResponse.statusCode {
//                case 200:
//                    if starred {
//                        CDStarred.deleteItemIds(itemIds: [item.id], in: NewsData.shared.container.viewContext)
//                    } else {
//                        CDUnstarred.deleteItemIds(itemIds: [item.id], in: NewsData.shared.container.viewContext)
//                    }
//                default:
//                    break
//                }
//            }
//        } catch(let error) {
//            throw NetworkError.generic(message: error.localizedDescription)
//        }
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

            try await FolderImporter().fetchFolders(Router.folders.urlRequest())
            try await FeedImporter().fetchFeeds(Router.feeds.urlRequest())
            try await ItemImporter().fetchItems(unreadRouter.urlRequest())
            try await ItemImporter().fetchItems(starredRouter.urlRequest())
//            try await ItemPruner().pruneItems(daysOld: Preferences().keepDuration)
            DispatchQueue.main.async {
                NewsManager.shared.syncSubject.send(SyncTimes(previous: 0, current: Date().timeIntervalSinceReferenceDate))
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
        do {
            if let container = NewsData.shared.container {
                let context = ModelContext(container)
                let items = try context.fetch(FetchDescriptor<Item>())
                if items.count == 0 {
                try await self.initialSync()
                return
            }
            }
        } catch { }
        
        do {
            /*
            if let localRead = CDRead.all(), !localRead.isEmpty {
                let readParameters = ["items": localRead]
                let readRouter = Router.itemsRead(parameters: readParameters)
                async let (_, readResponse) = session.data(for: readRouter.urlRequest(), delegate: nil)
                let readItemsResponse = try await readResponse
                if let httpReadResponse = readItemsResponse as? HTTPURLResponse {
                    switch httpReadResponse.statusCode {
                    case 200:
                        CDRead.clear()
                    default:
                        break
                    }
                }
            }
            
            if let localStarred = CDStarred.all(), !localStarred.isEmpty {
                if let starredItems = CDItem.items(itemIds: localStarred) {
                    var params: [Any] = []
                    for starredItem in starredItems {
                        var param: [String: Any] = [:]
                        param["feedId"] = starredItem.feedId
                        param["guidHash"] = starredItem.guidHash
                        params.append(param)
                    }
                    let starredParameters = ["items": params]
                    let starredRouter = Router.itemsStarred(parameters: starredParameters)
                    async let (_, starredResponse) = session.data(for: starredRouter.urlRequest(), delegate: nil)
                    let starredItemsResponse = try await starredResponse
                    if let httpStarredResponse = starredItemsResponse as? HTTPURLResponse {
                        switch httpStarredResponse.statusCode {
                        case 200:
                            CDStarred.clear()
                        default:
                            break
                        }
                    }
                }
            }
            
            if let localUnstarred = CDUnstarred.all(), !localUnstarred.isEmpty {
                if let unstarredItems = CDItem.items(itemIds: localUnstarred) {
                    var params: [Any] = []
                    for unstarredItem in unstarredItems {
                        var param: [String: Any] = [:]
                        param["feedId"] = unstarredItem.feedId
                        param["guidHash"] = unstarredItem.guidHash
                        params.append(param)
                    }
                    let unStarredParameters = ["items": params]
                    let unStarredRouter = Router.itemsUnstarred(parameters: unStarredParameters)
                    async let (_, unStarredResponse) = session.data(for: unStarredRouter.urlRequest(), delegate: nil)
                    let unStarredItemsResponse = try await unStarredResponse
                    if let httpUnStarredResponse = unStarredItemsResponse as? HTTPURLResponse {
                        switch httpUnStarredResponse.statusCode {
                        case 200:
                            CDUnstarred.clear()
                        default:
                            break
                        }
                    }
                }
            }
*/
            let newestKnownLastModified: Int32 = 0 // CDItem.lastModified()
            Preferences().lastModified = newestKnownLastModified

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

//            try await ItemPruner().pruneItems(daysOld: Preferences().keepDuration)
            try await FolderImporter().fetchFolders(Router.folders.urlRequest())
            try await FeedImporter().fetchFeeds(Router.feeds.urlRequest())
            try await ItemImporter().fetchItems(updatedItemRouter.urlRequest())

            DispatchQueue.main.async {
                NewsManager.shared.syncSubject.send(SyncTimes(previous: Double(newestKnownLastModified), current: Date().timeIntervalSinceReferenceDate))
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

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
//            TODO let deleteRouter = Router.deleteFeed(id: id)
//            do {
//                let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
//                if let httpResponse = deleteResponse as? HTTPURLResponse {
//                    print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                    switch httpResponse.statusCode {
//                    case 200:
//                        break
//                    case 404:
//                        try await CDItem.deleteItems(with: Int32(id))
//                        try await CDFeed.delete(id: Int32(id))
//                        throw NetworkError.feedDoesNotExist
//                    default:
//                        throw NetworkError.feedErrorDeleting
//                    }
//                }
//            } catch let error as NetworkError {
//                throw error
//            } catch(let error) {
//                throw NetworkError.generic(message: error.localizedDescription)
//            }
    }

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
