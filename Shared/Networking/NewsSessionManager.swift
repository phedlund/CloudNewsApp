//
//  NewsSessionManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation

typealias SyncCompletionBlock = () -> Void
typealias SyncCompletionBlockNewItems = (_ newItems: [ItemProtocol]) -> Void

//class NewsSessionM: URLSession {
//
////    static let shared = NewsSessionManager()
//
//    override init() {
//        let configuration = URLSessionConfiguration.background(withIdentifier: "com.peterandlinda.CloudNews.background")
//        super.init(configuration: configuration)
//    }
//
//}

struct ProductStatus {
    var name: String
    var version: String
}

class NewsManager {

    static let shared = NewsManager()
    static let session = URLSession.shared //(configuration: URLSessionConfiguration.background(withIdentifier: "com.peterandlinda.CloudNews.background"))
    var syncTimer: Timer?
    
    init() {
        self.setupSyncTimer()
    }
    
    func setupSyncTimer() {
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
    }

    func status() async throws -> ProductStatus {
        let router = StatusRouter.status
        let (data, _ /*response*/) = try await URLSession.shared.data(for: router.urlRequest(), delegate: nil)
        let decoder = JSONDecoder()
        let result = try decoder.decode(CloudStatus.self, from: data)
        let productStatus = ProductStatus(name: result.productname, version: result.versionstring)
        return productStatus
    }

    func version() async throws -> String {
        let router = Router.version
        do {
            let (data, _) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            let decoder = JSONDecoder()
            let result = try decoder.decode(Status.self, from: data)
            return result.version ?? ""
        } catch {
            throw PBHError.networkError("Unknown login error")
        }
    }

    func addFeed(url: String) async throws {
        let router = Router.addFeed(url: url, folder: 0)
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
                        CDFeed.update(feeds: feedArray)
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
                                }
                                break
                            default:
                                throw PBHError.networkError("Error adding feed")
                            }
                        }
                    }
                case 405:
                    throw PBHError.networkError("Method not allowed")
                case 409:
                    throw PBHError.networkError("The feed already exists")
                case 422:
                    throw PBHError.networkError("The feed could not be read. It most likely contains errors")
                default:
                    throw PBHError.networkError("Error adding feed")
                }
            }
        } catch {
            throw PBHError.networkError("Error adding feed")
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
                        CDFolder.update(folders: folderArray)
                    }
                case 405:
                    throw PBHError.networkError("Method not allowed")
                case 409:
                    throw PBHError.networkError("The folder already exists")
                case 422:
                    throw PBHError.networkError("The folder name is invalid.")
                default:
                    throw PBHError.networkError("Error adding folder")
                }
            }
        } catch {
            throw PBHError.networkError("Error adding folder")
        }
    }

    func markRead(items: [CDItem], unread: Bool) async throws {
        do {
            if items.isEmpty {
                return
            }
            if items.count > 1 {
                try await CDItem.markRead(items: items, unread: unread)
            } else {
                try await CDItem.markRead(item: items[0], unread: unread)
            }
            let itemIds = items.map( { $0.id } )
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
        } catch {
            throw PBHError.networkError("Error marking items read")
        }
    }

    func markStarred(item: CDItem, starred: Bool) async throws {
        do {
            try await CDItem.markStarred(itemId: item.id, state: starred)
            let parameters: ParameterDict = ["items": [["feedId": item.feedId,
                                                        "guidHash": item.guidHash as Any]]]
            var router: Router
            if starred {
                router = Router.itemsStarred(parameters: parameters)
            } else {
                router = Router.itemsUnstarred(parameters: parameters)
            }
            let (data, response) = try await NewsManager.session.data(for: router.urlRequest(), delegate: nil)
            //(for: request, from: body ?? Data(), delegate: nil)
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


    //            NewsSessionManager.shared.request(router).responseData { response in
    //                switch response.result {
    //                case .success:
    //                    if starred {
    //                        CDStarred.deleteItemIds(itemIds: [item.id], in: NewsData.mainThreadContext)
    //                    } else {
    //                        CDUnstarred.deleteItemIds(itemIds: [item.id], in: NewsData.mainThreadContext)
    //                    }
    //                default:
    //                    break
    //                }
    //                completion()
    //            }


        } catch {
            throw PBHError.networkError("Error marking item starred")
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
        let starredItemRouter = Router.items(parameters: starredParameters)

        do {
            // 1.
            async let (unreadData, _ /*unreadResponse*/) = NewsManager.session.data(for: unreadRouter.urlRequest(), delegate: nil)
            // 2.
            async let (starredData, _ /*starredResponse*/) = NewsManager.session.data(for: starredItemRouter.urlRequest(), delegate: nil)
            // 3.
            async let (folderData, _ /*folderResponse*/) = NewsManager.session.data(for: Router.folders.urlRequest(), delegate: nil)
            // 4.
            async let (feedsData, _ /*feedsResponse*/) = NewsManager.session.data(for: Router.feeds.urlRequest(), delegate: nil)

            let unreadItemsData = try await unreadData
            let starredItemsData = try await starredData
            let foldersData = try await folderData
            let allFeedsData = try await feedsData

            let unreadItems: Items = try getType(from: unreadItemsData)
            let starredItems: Items = try getType(from: starredItemsData)
            let folders: Folders = try getType(from: foldersData)
            let feeds: Feeds = try getType(from: allFeedsData)

            if let items = unreadItems.items {
                try await CDItem.add(items: items, using: NewsData.mainThreadContext)
            }
            if let itemsStarred = starredItems.items {
                try await CDItem.add(items: itemsStarred, using: NewsData.mainThreadContext)
            }
            if let folders = folders.folders {
                CDFolder.update(folders: folders)
            }

//            if let newestItemId = feeds.newestItemId, let starredCount = feeds.starredCount {
//                CDFeeds.update(starredCount: starredCount, newestItemId: newestItemId)
//            }
            if let feeds = feeds.feeds {
                CDFeed.update(feeds: feeds)
            }
            updateBadge()
            let articleImageFetcher = ItemImageFetcher()
            let favIconFetcher = FavIconFetcher()
            Task {
                try? await favIconFetcher.fetch()
                try? await articleImageFetcher.itemImages()
            }

            NotificationCenter.default.post(name: .syncComplete, object: nil)
        } catch(let error) {
            print(error.localizedDescription)
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

            try await FolderImporter(persistentContainer: NewsData.persistentContainer).performImport()
            try await FeedImporter(persistentContainer: NewsData.persistentContainer).performImport()
            try await ItemImporter(persistentContainer: NewsData.persistentContainer).performImport()
            try await CDItem.deleteOldItems()
            let articleImageFetcher = ItemImageFetcher()
            let favIconFetcher = FavIconFetcher()
            Task {
                try? await favIconFetcher.fetch()
                try? await articleImageFetcher.itemImages()
            }

            NotificationCenter.default.post(name: .syncComplete, object: nil)
        } catch(let error) {
            print(error.localizedDescription)
        }

/*
        //5
        func folders(completion: @escaping SyncCompletionBlock) {
//            NewsSessionManager.shared.request(Router.folders).responseDecodable(completionHandler: { (response: DataResponse<Folders>) in
//                if let folders = response.value?.folders {
//                    var addedFolders = [FolderSync]()
//                    var deletedFolders = [FolderSync]()
//                    let ids = folders.map({ FolderSync.init(id: $0.id, name: $0.name ?? "Untitled") })
//                    if let knownFolders = CDFolder.all() {
//                        let knownIds = knownFolders.map({ FolderSync.init(id: $0.id, name: $0.name ?? "Untitled") })
//                        addedFolders = ids.filter({
//                            return !knownIds.contains($0)
//                        })
//                        deletedFolders = knownIds.filter({
//                            return !ids.contains($0)
//                        })
//                    }
//                    CDFolder.update(folders: folders)
//                    NotificationCenter.default.post(name: .folderSync, object: self, userInfo: ["added": addedFolders, "deleted": deletedFolders])
//                    CDFolder.delete(ids: deletedFolders.map( { $0.id }), in: NewsData.mainThreadContext)
//                }
//                completion()
//            })
        }
        
        //6
        func feeds(completion: @escaping SyncCompletionBlock) {
//            NewsSessionManager.shared.request(Router.feeds).responseDecodable(completionHandler: { (response: DataResponse<Feeds>) in
//                if let newestItemId = response.value?.newestItemId, let starredCount = response.value?.starredCount {
//                    CDFeeds.update(starredCount: starredCount, newestItemId: newestItemId)
//                }
//                if let feeds = response.value?.feeds {
//                    var addedFeeds = [FeedSync]()
//                    var deletedFeeds = [FeedSync]()
//                    let ids = feeds.map({ FeedSync.init(id: $0.id, title: $0.title ?? "Untitled", folderId: $0.folderId) })
//                    if let knownFeeds = CDFeed.all() {
//                        let knownIds = knownFeeds.map({ FeedSync.init(id: $0.id, title: $0.title ?? "Untitled", folderId: $0.folderId) })
//                        addedFeeds = ids.filter({
//                            return !knownIds.contains($0)
//                        })
//                        deletedFeeds = knownIds.filter({
//                            return !ids.contains($0)
//                        })
//                    }
//                    CDFeed.delete(ids: deletedFeeds.map( { $0.id }), in: NewsData.mainThreadContext)
//                    if let allItems = CDItem.all() {
//                        let deletedFeedItems = allItems.filter({
//                            return deletedFeeds.map( { $0.id } ).contains($0.feedId) &&
//                                !addedFeeds.map( { $0.id }).contains($0.feedId)
//                        })
//                        let deletedFeedItemIds = deletedFeedItems.map({ $0.id })
//                        CDItem.delete(ids: deletedFeedItemIds, in: NewsData.mainThreadContext)
//                    }
//                    CDFeed.update(feeds: feeds)
//                    NotificationCenter.default.post(name: .feedSync, object: self, userInfo: ["added": addedFeeds, "deleted": deletedFeeds])
//                }
//                completion()
//            })
        }
        
        //7
        func items(completion: @escaping SyncCompletionBlock) {
            let updatedParameters: ParameterDict = ["type": 3,
                                                 "lastModified": CDItem.lastModified(),
                                                 "id": 0]
            
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)
//            NewsSessionManager.shared.request(updatedItemRouter).responseDecodable(completionHandler: { (response: DataResponse<Items>) in
//                if let items = response.value?.items {
//                    CDItem.update(items: items, completion: { (newItems) in
//                        for newItem in newItems {
//                            let feed = CDFeed.feed(id: newItem.feedId)
//                            let notification = NSUserNotification()
//                            notification.identifier = NSUUID().uuidString
//                            notification.title = "CloudNews"
//                            notification.subtitle = feed?.title ?? "New article"
//                            notification.informativeText = newItem.title ?? ""
//                            notification.soundName = NSUserNotificationDefaultSoundName
//                            let notificationCenter = NSUserNotificationCenter.default
//                            notificationCenter.deliver(notification)
//                        }
//                    })
//                }
//                completion()
//            })
        }
        
//        localRead {
//            localStarred {
//                localUnstarred {
//                    folders {
//                        feeds {
//                            items {
//                                self.updateBadge()
//                                completion()
//                            }
//                        }
//                    }
//                }
//            }
//        }
        */
    }

    func moveFeed(feed: CDFeed, to folder: Int32) async throws {
        let moveFeedRouter = Router.moveFeed(id: Int(feed.id), folder: Int(folder))
        do {
            let (_, moveResponse) = try await NewsManager.session.data(for: moveFeedRouter.urlRequest(), delegate: nil)
            if let httpResponse = moveResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 404:
                    break // handle error
                default:
                    break
                }
            }
        }
    }

    func renameFeed(feed: CDFeed, to name: String) async throws {
        let renameRouter = Router.renameFeed(id: Int(feed.id), newName: name)
        do {
            let (_, renameResponse) = try await NewsManager.session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 404:
                    break // handle error
                default:
                    break
                }
                //                        case 404:
                //                            message = @"The feed does not exist.";
                //                            break;
                //                        case 405:
                //                            message = @"Please update the News app on the server to enable feed renaming.";
                //                            break;
                //                        default:
                //                            message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'.", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                //                            break;

            }
        } catch {
            //
        }
    }

    func deleteFeed(_ id: Int) async throws {
        let deleteRouter = Router.deleteFeed(id: id)
        do {
            let (_, deleteResponse) = try await NewsManager.session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 404:
                    break // "The feed does not exist."
                default:
                    break
                }
            }
        } catch {
            throw PBHError.networkError("Error deleting feed")
        }
    }

    func renameFolder(folder: CDFolder, to name: String) async throws {
        let renameRouter = Router.renameFolder(id: Int(folder.id), newName: name)
        do {
            let (_, renameResponse) = try await NewsManager.session.data(for: renameRouter.urlRequest(), delegate: nil)
            if let httpResponse = renameResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 404:
                    break // handle error
                default:
                    break
                }
//                    case 404:
//                        message = @"The folder does not exist.";
//                        break;
//                    case 409:
//                        message = @"A folder with this name already exists.";
//                        break;
//                    case 422:
//                        message = @"The folder name is invalid";
//                        break;
//                    default:
//                        message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'.", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
//                        break;
            }
        } catch {
            //
        }
    }


    func deleteFolder(_ id: Int) async throws {
        let deleteRouter = Router.deleteFolder(id: id)
        do {
            let (_, deleteResponse) = try await NewsManager.session.data(for: deleteRouter.urlRequest(), delegate: nil)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                switch httpResponse.statusCode {
                case 404:
                    break // "The folder does not exist."
                default:
                    break
                }
            }
        } catch {
            throw PBHError.networkError("Error deleting folder")
        }
    }

    func updateBadge() {
//        let unreadCount = CDItem.unreadCount()
//        if unreadCount > 0 {
////            App.dockTile.badgeLabel = "\(unreadCount)"
//        } else {
////            App.dockTile.badgeLabel = nil
//        }
    }

}
