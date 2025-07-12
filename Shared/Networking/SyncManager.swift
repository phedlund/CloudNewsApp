//
//  DataManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/26/24.
//

#if os(macOS)
import AppKit
#endif
import Foundation
import SwiftData
import UserNotifications
import WidgetKit

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
    private var feedDTOs = [FeedDTO]()
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
            Preferences().didSyncInBackground = true
        }
    }

    func sync() async throws -> NewsStatusDTO? {
        syncManagerReader.isSyncing = true
        let itemCount = try await databaseActor.itemCount()
        let currentStatus = try await newsStatus()
        if itemCount == 0 {
            try await initialSync()
        } else {
            try await repeatSync()
        }
        WidgetCenter.shared.reloadAllTimelines()
        syncManagerReader.isSyncing = false
        return currentStatus
    }

    private func newsStatus() async throws -> NewsStatusDTO? {
        let statusRequest = try Router.status.urlRequest()
        let statusData = try await URLSession.shared.data (for: statusRequest).0
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(NewsStatusDTO.self, from: statusData) else {
            return nil
        }
        return decodedResponse
    }

    /*
     Initial sync

     1. unread articles: GET /items?type=3&getRead=false&batchSize=-1
     2. starred articles: GET /items?type=2&getRead=true&batchSize=-1
     3. folders: GET /folders
     4. feeds: GET /feeds
     */

    private func initialSync() async throws {
        let foldersRequest = try Router.folders.urlRequest()
        let feedsRequest = try Router.feeds.urlRequest()

        let unreadParameters: ParameterDict = ["type": 3,
                                               "getRead": false,
                                               "batchSize": -1]
        let unreadRequest = try Router.items(parameters: unreadParameters).urlRequest()

        let starredParameters: ParameterDict = ["type": 2,
                                                "getRead": true,
                                                "batchSize": -1]
        let starredRequest = try Router.items(parameters: starredParameters).urlRequest()

        let results = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var results = [Int: Data]()

            group.addTask {
                return (1, try await URLSession.shared.data (for: foldersRequest).0)
            }
            group.addTask {
                return (2, try await URLSession.shared.data (for: feedsRequest).0)
            }
            group.addTask {
                return (3, try await URLSession.shared.data (for: unreadRequest).0)
            }
            group.addTask {
                return (4, try await URLSession.shared.data (for: starredRequest).0)
            }

            for try await (index, result) in group {
                results[index] = result
            }

            return results
        }

        if let foldersData = results[1] as Data?, !foldersData.isEmpty {
            parseFolders(data: foldersData)
        }
        if let feedsData = results[2] as Data?, !feedsData.isEmpty {
            parseFeeds(data: feedsData)
        }
        if let unreadData = results[3] as Data?, !unreadData.isEmpty {
            parseItems(data: unreadData)
        }
        if let starredData = results[4] as Data?, !starredData.isEmpty {
            parseItems(data: starredData)
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

    private func repeatSync() async throws {
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

        var localStarredParameters = [StarredParameter]()
        let starredIdentifiers = try await databaseActor.allModelIds(FetchDescriptor<Starred>())
        for identifier in starredIdentifiers {
            if let parameters = try await databaseActor.fetchStarredParameter(by: identifier) {
                localStarredParameters.append(parameters)
            }
        }

        if !localStarredParameters.isEmpty {
            var params = [Any]()
            for starredItem in localStarredParameters {
                var param: [String: Any] = [:]
                param["feedId"] = starredItem.feedId
                param["guidHash"] = starredItem.guidHash
                params.append(param)
            }
            let starredParameters = ["items": params]
            let starredRouter = Router.itemsStarred(parameters: starredParameters)
            async let (_, starredResponse) = URLSession.shared.data(for: starredRouter.urlRequest(), delegate: nil)
            let starredItemsResponse = try await starredResponse
            if let httpStarredResponse = starredItemsResponse as? HTTPURLResponse {
                switch httpStarredResponse.statusCode {
                case 200:
                    await databaseActor.deleteAll(Starred.self)
                default:
                    break
                }
            }
        }

        var localUnstarredParameters = [StarredParameter]()
        let unStarredIdentifiers = try await databaseActor.allModelIds(FetchDescriptor<Unstarred>())
        for identifier in unStarredIdentifiers {
            if let parameters = try await databaseActor.fetchStarredParameter(by: identifier) {
                localUnstarredParameters.append(parameters)
            }
        }

        if !localUnstarredParameters.isEmpty {
            var params = [Any]()
            for unstarredItem in localUnstarredParameters {
                var param: [String: Any] = [:]
                param["feedId"] = unstarredItem.feedId
                param["guidHash"] = unstarredItem.guidHash
                params.append(param)
            }
            let unstarredParameters = ["items": params]
            let unstarredRouter = Router.itemsStarred(parameters: unstarredParameters)
            async let (_, unstarredResponse) = URLSession.shared.data(for: unstarredRouter.urlRequest(), delegate: nil)
            let unstarredItemsResponse = try await unstarredResponse
            if let httpStarredResponse = unstarredItemsResponse as? HTTPURLResponse {
                switch httpStarredResponse.statusCode {
                case 200:
                    await databaseActor.deleteAll(Unstarred.self)
                default:
                    break
                }
            }
        }

        let foldersRequest = try Router.folders.urlRequest()
        let feedsRequest = try Router.feeds.urlRequest()

        let newestKnownLastModified = await databaseActor.maxLastModified()
        Preferences().lastModified = Int32(newestKnownLastModified)
        let updatedParameters: ParameterDict = ["type": 3,
                                                "lastModified": newestKnownLastModified,
                                                "id": 0]
        let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

        let itemsRequest = try updatedItemRouter.urlRequest()

        let results = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var results = [Int: Data]()

            group.addTask { [self] in
                try await pruneItems()
                return (0, Data())
            }
            group.addTask {
                return (1, try await URLSession.shared.data (for: foldersRequest).0)
            }
            group.addTask {
                return (2, try await URLSession.shared.data (for: feedsRequest).0)
            }
            group.addTask {
                return (3, try await URLSession.shared.data (for: itemsRequest).0)
            }

            for try await (index, result) in group {
                results[index] = result
            }

            return results
        }

        if let foldersData = results[1] as Data?, !foldersData.isEmpty {
            parseFolders(data: foldersData)
        }
        if let feedsData = results[2] as Data?, !feedsData.isEmpty {
            parseFeeds(data: feedsData)
        }
        if let itemsData = results[3] as Data?, !itemsData.isEmpty {
            parseItems(data: itemsData)
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
        let folderIds = decodedResponse.folders.map( { $0.id } )
        Task {
            do {
                try await databaseActor.pruneFolders(serverFolderIds: folderIds)
            } catch {
                //
            }
        }
    }

    private func parseFeeds(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FeedsDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        Task {
            self.feedDTOs = decodedResponse.feeds
            let allNode = Node(id: Constants.allNodeGuid, type: .all, title: "All Articles", pinned: 1)
            await databaseActor.insert(allNode)
            let starredNode = Node(id: Constants.starNodeGuid, type: .starred, title: "Starred Articles", pinned: 1)
            await databaseActor.insert(starredNode)
            for folderDTO in foldersDTO.folders {
                var feeds = [Node]()
                let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == folderDTO.id })
                for feedDTO in feedDTOs  {
                    let feedToStore = await Feed(item: feedDTO)
                    let type = NodeType.feed(id: feedDTO.id)
                    feedNode = Node(id: type.description, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: feedToStore.favIconURL, errorCount: feedDTO.updateErrorCount > 20 ? 1 : 0, pinned: feedDTO.pinned ? 1 : 0, favIcon: feedToStore.favIcon)
                    feeds.append(feedNode)
                    await databaseActor.insert(feedToStore)
                }
                let type = NodeType.folder(id: folderDTO.id)
                folderNode = Node(id: type.description, type: type, title: folderDTO.name, isExpanded: folderDTO.opened, favIconURL: nil, children: feeds, pinned: 1)
                let feedsWithUpdateErrorCount = feeds.filter { $0.errorCount > 0 }
                if !feedsWithUpdateErrorCount.isEmpty {
                    folderNode.errorCount = 1
                }
                await databaseActor.insert(folderNode)
                let itemToStore = Folder(item: folderDTO)
                await databaseActor.insert(itemToStore)
            }
            let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == nil })
            for feedDTO in feedDTOs {
                let feedToStore = await Feed(item: feedDTO)
                let type = NodeType.feed(id: feedDTO.id)
                feedNode = Node(id: type.description, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: feedToStore.favIconURL, errorCount: feedDTO.updateErrorCount > 20 ? 1 : 0, pinned: feedDTO.pinned ? 1 : 0, favIcon: feedToStore.favIcon)
                await databaseActor.insert(feedToStore)
                await databaseActor.insert(feedNode)
            }
            let feedIds = decodedResponse.feeds.map( { $0.id } )
            Task {
                do {
                    try await databaseActor.pruneFeeds(serverFeedIds: feedIds)
                } catch {
                    //
                }
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
            let unreadCount = try await databaseActor.fetchCount(predicate: #Predicate<Item> { $0.unread == true })
            await MainActor.run {
                UNUserNotificationCenter.current().setBadgeCount(unreadCount)
            }
        }
    }

    private func pruneItems() async throws {
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
