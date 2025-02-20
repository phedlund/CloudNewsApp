//
//  DataManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/26/24.
//


import Foundation
import SwiftData

@Observable
final class SyncManagerReader {
    var isSyncing = false
}

@Observable
final class SyncManager: @unchecked Sendable {
    private let databaseActor: NewsDataModelActor
    private var backgroundSession: URLSession?
    var syncManagerReader = SyncManagerReader()

    private var foldersDTO = FoldersDTO(folders: [FolderDTO]())
    private var folderNode = Node(id: "", type: .empty, title: "")
    private var feedNode = Node(id: "", type: .empty, title: "")

    init(databaseActor: NewsDataModelActor) {
        self.databaseActor = databaseActor
    }

    func configureSession() {
        let backgroundSessionConfig = URLSessionConfiguration.background(withIdentifier: Constants.appUrlSessionId)
        backgroundSessionConfig.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: backgroundSessionConfig)
    }

    func backgroundSync() async {
        try? await pruneItems()
        if let backgroundSession {
            let foldersRequest = try? Router.folders.urlRequest()
            let foldersResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: foldersRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: foldersRequest!)
                task.taskDescription = "folders"
                task.resume ()
            }

            if let data = foldersResponse {
                parseFolders(data: data.0)
            }

            let feedsRequest = try? Router.feeds.urlRequest()

            let feedsResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: feedsRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: feedsRequest!)
                task.taskDescription = "feeds"
                task.resume ()
            }

            if let data = feedsResponse {
                parseFeeds(data: data.0)
            }


            let newestKnownLastModified = await databaseActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try? updatedItemRouter.urlRequest()

            let itemsResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: itemsRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: itemsRequest!)
                task.taskDescription = "items"
                task.resume ()
            }

            if let data = itemsResponse {
                parseItems(data: data.0)
            }
        }
    }

    func processSessionData() {
        backgroundSession?.getAllTasks { [self] tasks in
            for task in tasks {
                if task.state == .suspended || task.state == .canceling { continue }
                // NOTE: It seems the task state is .running when this is called, instead of .completed as one might expect.

                if let dlTask = task as? URLSessionDownloadTask {
                    if let url = dlTask.response?.url {
                        if let data = try? Data(contentsOf: url) {
                            switch dlTask.taskDescription {
                            case "folders":
                                parseFolders(data: data)
                            case "feeds":
                                parseFeeds(data: data)
                            case "items":
                                parseItems(data: data)
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    func sync() async {
        do {
            syncManagerReader.isSyncing = true
            let itemCount = try await databaseActor.itemCount()
            if itemCount == 0 {
                await initialSync()
            } else {
                await repeatSync()
            }
            syncManagerReader.isSyncing = false
        } catch {
            syncManagerReader.isSyncing = false
        }
    }

    /*
     Initial sync

     1. unread articles: GET /items?type=3&getRead=false&batchSize=-1
     2. starred articles: GET /items?type=2&getRead=true&batchSize=-1
     3. folders: GET /folders
     4. feeds: GET /feeds
     */

    func initialSync() async {
        do {
            let foldersRequest = try Router.folders.urlRequest()
            let feedsRequest = try Router.feeds.urlRequest()

            let unreadParameters: ParameterDict = ["type": 3,
                                                   "getRead": false,
                                                   "batchSize": -1]
            let unreadRouter = Router.items(parameters: unreadParameters)

            let starredParameters: ParameterDict = ["type": 2,
                                                    "getRead": true,
                                                    "batchSize": -1]
            let starredRouter = Router.items(parameters: starredParameters)

            let foldersData = try await URLSession.shared.data (for: foldersRequest).0
            let feedsData = try await URLSession.shared.data (for: feedsRequest).0
            let unreadItemsData = try await URLSession.shared.data (for: unreadRouter.urlRequest()).0
            let starredItemsData = try await URLSession.shared.data (for: starredRouter.urlRequest()).0

            parseFolders(data: foldersData)
            parseFeeds(data: feedsData)
            parseItems(data: unreadItemsData)
            parseItems(data: starredItemsData)
        } catch {

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

    func repeatSync() async {
        do {
            try await pruneItems()

            var localReadIds = [Int64]()
            let identifiers = try await databaseActor.allModelIds(FetchDescriptor<Read>())
            for identifier in identifiers {
                if let itemId = try await databaseActor.fetchItemId(by: identifier) {
                    localReadIds.append(itemId)
                }
            }

            if !localReadIds.isEmpty {
                let readParameters = ["items": localReadIds]
                let readRouter = Router.itemsRead(parameters: readParameters)
                async let (_, readResponse) = URLSession.shared.data(for: readRouter.urlRequest(), delegate: nil)
                let readItemsResponse = try await readResponse
                if let httpReadResponse = readItemsResponse as? HTTPURLResponse {
                    switch httpReadResponse.statusCode {
                    case 200:
                        await databaseActor.deleteAll(Read.self)
                    default:
                        break
                    }
                }
            }

            var localUnreadIds = [Int64]()
            let unreadIdentifiers = try await databaseActor.allModelIds(FetchDescriptor<Unread>())
            for identifier in unreadIdentifiers {
                if let itemId = try await databaseActor.fetchItemId(by: identifier) {
                    localUnreadIds.append(itemId)
                }
            }

            if !localUnreadIds.isEmpty {
                let unreadParameters = ["items": localUnreadIds]
                let unreadRouter = Router.itemsUnread(parameters: unreadParameters)
                async let (_, unreadResponse) = URLSession.shared.data(for: unreadRouter.urlRequest(), delegate: nil)
                let unreadItemsResponse = try await unreadResponse
                if let httpUnreadResponse = unreadItemsResponse as? HTTPURLResponse {
                    switch httpUnreadResponse.statusCode {
                    case 200:
                        await databaseActor.deleteAll(Unread.self)
                    default:
                        break
                    }
                }
            }
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


            let foldersRequest = try Router.folders.urlRequest()
            let feedsRequest = try Router.feeds.urlRequest()

            let newestKnownLastModified = await databaseActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)
            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try updatedItemRouter.urlRequest()

            let foldersData = try await URLSession.shared.data (for: foldersRequest).0
            let feedsData = try await URLSession.shared.data (for: feedsRequest).0
            let itemsData = try await URLSession.shared.data (for: itemsRequest).0
            parseFolders(data: foldersData)
            parseFeeds(data: feedsData)
            parseItems(data: itemsData)
        } catch {

        }
    }

    private func parseFolders(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FoldersDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        self.foldersDTO = decodedResponse

//        Task {
//            self.foldersDTO = decodedResponse
//            let allNode = Node(id: Constants.allNodeGuid, title: "All Articles")
//            await databaseActor.insert(allNode)
//            let starredNode = Node(id: Constants.starNodeGuid, title: "Starred Articles")
//            for eachItem in decodedResponse.folders {
//                let itemToStore = Folder(item: eachItem)
//                await databaseActor.insert(itemToStore)
//            }
//            try? await databaseActor.save()
//        }
    }

    private func parseFeeds(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FeedsDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        Task {
            let allNode = Node(id: Constants.allNodeGuid, type: .all, title: "All Articles")
            await databaseActor.insert(allNode)
            let starredNode = Node(id: Constants.starNodeGuid, type: .starred, title: "Starred Articles")
            await databaseActor.insert(starredNode)
            for folderDTO in foldersDTO.folders {
                var feeds = [Node]()
                let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == folderDTO.id })
                for feedDTO in feedDTOs  {
                    let feedToStore = Feed(item: feedDTO)
                    let type = NodeType.feed(id: feedDTO.id)
                    feedNode = Node(id: type.description, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: feedToStore.favIconURL)
                    feeds.append(feedNode)
                    await databaseActor.insert(feedToStore)
//                    await databaseActor.insert(feedNode)
                }
                let type = NodeType.folder(id: folderDTO.id)
                folderNode = Node(id: type.description, type: type, title: folderDTO.name, isExpanded: folderDTO.opened, favIconURL: nil, children: feeds, errorCount: 0)
                await databaseActor.insert(folderNode)
                let itemToStore = Folder(item: folderDTO)
                await databaseActor.insert(itemToStore)
            }
            let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == nil })
            for feedDTO in feedDTOs {
                let feedToStore = Feed(item: feedDTO)
                let type = NodeType.feed(id: feedDTO.id)
                feedNode = Node(id: type.description, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: feedToStore.favIconURL)
                await databaseActor.insert(feedToStore)
                await databaseActor.insert(feedNode)
            }
            try? await databaseActor.save()
        }
    }

    private func parseItems(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(ItemsDTO.self, from: data) else {
            return
        }
        Task {
            for eachItem in decodedResponse.items {
                let itemToStore = await Item(item: eachItem)
                await databaseActor.insert(itemToStore)
            }
            try? await databaseActor.save()
        }
    }

    func pruneItems() async throws {
        do {
            if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * Preferences().keepDuration), to: Date()) {
                print("limitDate: \(limitDate) date: \(Date())")
                try await databaseActor.delete(Item.self, where: #Predicate { $0.unread == false && $0.starred == false && $0.lastModified < limitDate } )
            }
        } catch {
            throw DatabaseError.itemsFailedImport
        }
    }

}
