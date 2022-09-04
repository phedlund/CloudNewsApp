//
//  NewsSessionManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018-2022 Peter Hedlund. All rights reserved.
//

import Foundation

struct ProductStatus {
    var name: String
    var version: String
}

class NewsManager {

    static let shared = NewsManager()
    static let session = URLSession.shared
    var syncTimer: Timer?
    
    init() {
        self.setupSyncTimer()
    }
    
    func setupSyncTimer() {
#if os(macOS)
        self.syncTimer?.invalidate()
        self.syncTimer = nil
        let interval = UserDefaults.standard.integer(forKey: "interval")
        if interval > 0 {
            var timeInterval: TimeInterval = 900
            switch interval {
            case 2: timeInterval = 30 * 60
            case 3: timeInterval = 60 * 60
            default: timeInterval = 15 * 60
            }
            self.syncTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { (_) in
                NotificationCenter.default.post(name: .syncInitiated, object: nil)
                Task {
                    try await self.sync()
                }
            }
        }
#endif
    }

    func status() async throws -> ProductStatus {
        let router = StatusRouter.status
        do {
            let (data, _) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            let decoder = JSONDecoder()
            let result = try decoder.decode(CloudStatus.self, from: data)
            let productStatus = ProductStatus(name: result.productname, version: result.versionstring)
            return productStatus
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func version() async throws -> String {
        let router = Router.version
        do {
            let (data, _) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            let decoder = JSONDecoder()
            let result = try decoder.decode(Status.self, from: data)
            return result.version ?? ""
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func addFeed(url: String, folderId: Int) async throws {
        let router = Router.addFeed(url: url, folder: folderId)
        do {
            let (data, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    if let feeds: Feeds = try getType(from: data),
                       let feedArray = feeds.feeds, let newFeed = feedArray.first {
                        let newFeedId = newFeed.id
                        try await CDFeed.add(feeds: feedArray, using: NewsData.mainThreadContext)
                        try NewsData.mainThreadContext.save()
                        let parameters: ParameterDict = ["batchSize": 200,
                                                         "offset": 0,
                                                         "type": 0,
                                                         "id": newFeedId,
                                                         "getRead": NSNumber(value: true)]
                        let router = Router.items(parameters: parameters)
                        let (data, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
                        if let httpResponse = response as? HTTPURLResponse {
                            print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                            print(String(data: data, encoding: .utf8) ?? "")
                            switch httpResponse.statusCode {
                            case 200:
                                if let items: Items = try getType(from: data),
                                   let itemsArray = items.items {
                                    try await CDItem.add(items: itemsArray, using: NewsData.mainThreadContext)
                                    try NewsData.mainThreadContext.save()
                                }
                            default:
                                throw PBHError.networkError(message: "Error adding feed")
                            }
                        }
                    }
                case 405:
                    throw PBHError.networkError(message: "Method not allowed")
                case 409:
                    throw PBHError.networkError(message: "The feed already exists")
                case 422:
                    throw PBHError.networkError(message: "The feed could not be read. It most likely contains errors")
                default:
                    throw PBHError.networkError(message: "Error adding feed")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }
    
    func addFolder(name: String) async throws {
        let router = Router.addFolder(name: name)
        do {
            let (data, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    if let folders: Folders = try getType(from: data),
                        let folderArray = folders.folders {
                        try await CDFolder.add(folders: folderArray, using: NewsData.mainThreadContext)
                        try NewsData.mainThreadContext.save()
                    }
                case 405:
                    throw PBHError.networkError(message: "Method not allowed")
                case 409:
                    throw PBHError.networkError(message: "The folder already exists")
                case 422:
                    throw PBHError.networkError(message: "The folder name is invalid.")
                default:
                    throw PBHError.networkError(message: "Error adding folder")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func markRead(items: [CDItem], unread: Bool) async throws {
        guard !items.isEmpty else {
            return
        }
        do {
            if items.count > 1 {
                try await CDItem.markRead(items: items, unread: unread)
            } else {
                try await CDItem.markRead(item: items[0], unread: unread)
            }
            let itemIds = items.map( { $0.id } )
            if unread {
                CDUnread.update(items: itemIds)
            } else {
                CDRead.update(items: itemIds)
            }
            let parameters: ParameterDict = ["items": itemIds]
            var router: Router
            if unread {
                router = Router.itemsUnread(parameters: parameters)
            } else {
                router = Router.itemsRead(parameters: parameters)
            }
            let (_, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if unread {
                        CDUnread.deleteItemIds(itemIds: itemIds, in: NewsData.mainThreadContext)
                    } else {
                        CDRead.deleteItemIds(itemIds: itemIds, in: NewsData.mainThreadContext)
                    }
                default:
                    break
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func markStarred(item: CDItem, starred: Bool) async throws {
        do {
            try await CDItem.markStarred(itemId: item.id, state: starred)
            let parameters: ParameterDict = ["items": [["feedId": item.feedId,
                                                        "guidHash": item.guidHash as Any]]]
            var router: Router
            if starred {
                CDStarred.update(items: [item.id])
                router = Router.itemsStarred(parameters: parameters)
            } else {
                CDUnstarred.update(items: [item.id])
                router = Router.itemsUnstarred(parameters: parameters)
            }
            let (data, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    if starred {
                        CDStarred.deleteItemIds(itemIds: [item.id], in: NewsData.mainThreadContext)
                    } else {
                        CDUnstarred.deleteItemIds(itemIds: [item.id], in: NewsData.mainThreadContext)
                    }
                default:
                    break
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
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

            try await FolderImporter(persistentContainer: NewsData.persistentContainer).download(Router.folders.urlRequest())
            try await FeedImporter(persistentContainer: NewsData.persistentContainer).download(Router.feeds.urlRequest())
            try await ItemImporter(persistentContainer: NewsData.persistentContainer).download(unreadRouter.urlRequest())
            try await ItemImporter(persistentContainer: NewsData.persistentContainer).download(starredRouter.urlRequest())
            try await CDItem.deleteOldItems()

            NotificationCenter.default.post(name: .syncComplete, object: nil)
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
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
            let count = try NewsData.mainThreadContext.count(for: CDItem.fetchRequest())
            if count == 0 {
                try await self.initialSync()
                return
            }
        } catch { }
        
        do {
            if let localRead = CDRead.all(), !localRead.isEmpty {
                let readParameters = ["items": localRead]
                let readRouter = Router.itemsRead(parameters: readParameters)
                async let (_, readResponse) = NewsManager.session.data(for: readRouter.urlRequest(), delegate: nil)
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
                    async let (_, starredResponse) = NewsManager.session.data(for: starredRouter.urlRequest(), delegate: nil)
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
                    async let (_, unStarredResponse) = NewsManager.session.data(for: unStarredRouter.urlRequest(), delegate: nil)
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

            let newestKnownLastModified = CDItem.lastModified()
            Preferences().lastModified = newestKnownLastModified

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            try await FolderImporter(persistentContainer: NewsData.persistentContainer).download(Router.folders.urlRequest())
            try await FeedImporter(persistentContainer: NewsData.persistentContainer).download(Router.feeds.urlRequest())
            try await ItemImporter(persistentContainer: NewsData.persistentContainer).download(updatedItemRouter.urlRequest())
            try await CDItem.deleteOldItems()

            NotificationCenter.default.post(name: .syncComplete, object: nil)
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func moveFeed(feed: CDFeed, to folder: Int32) async throws {
        let moveFeedRouter = Router.moveFeed(id: Int(feed.id), folder: Int(folder))
        do {
            let (_, moveResponse) = try await NewsManager.session.data(for: moveFeedRouter.urlRequest(), delegate: nil)
            if let httpResponse = moveResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw PBHError.networkError(message: "The feed does not exist")
                default:
                    throw PBHError.networkError(message: "Error moving feed")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func renameFeed(feed: CDFeed, to name: String) async throws {
        let renameRouter = Router.renameFeed(id: Int(feed.id), newName: name)
        do {
            let (_, renameResponse) = try await NewsManager.session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw PBHError.networkError(message: "The feed does not exist")
                case 405:
                    throw PBHError.networkError(message: "Please update the News app on the server to enable feed renaming.")
                default:
                    throw PBHError.networkError(message: "Error renaming feed")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func deleteFeed(_ id: Int) async throws {
        let deleteRouter = Router.deleteFeed(id: id)
        do {
            let (_, deleteResponse) = try await NewsManager.session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw PBHError.networkError(message: "The feed does not exist")
                default:
                    throw PBHError.networkError(message: "Error deleting feed")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func renameFolder(folder: CDFolder, to name: String) async throws {
        let renameRouter = Router.renameFolder(id: Int(folder.id), newName: name)
        do {
            let (_, renameResponse) = try await NewsManager.session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw PBHError.networkError(message: "The folder does not exist")
                case 409:
                    throw PBHError.networkError(message: "The folder already exists")
                case 422:
                    throw PBHError.networkError(message: "The folder name is invalid.")
                default:
                    throw PBHError.networkError(message: "Error renaming folder")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    func deleteFolder(_ id: Int) async throws {
        let deleteRouter = Router.deleteFolder(id: id)
        do {
            let (_, deleteResponse) = try await NewsManager.session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    throw PBHError.networkError(message: "The folder does not exist")
                default:
                    throw PBHError.networkError(message: "Error deleting folder")
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

}
