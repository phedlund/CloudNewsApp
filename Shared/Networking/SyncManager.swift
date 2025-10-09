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
import SwiftSoup
import SwiftUI
import UserNotifications
import WidgetKit

enum SyncState: CustomStringConvertible, Equatable {
    case idle
    case started
    case folders
    case feeds
    case articles(update: String)
    case unread
    case starred
    case favicons

    var description: String {
        switch self {
        case .idle:
            return ""
        case .started:
            return "Getting started…"
        case .folders:
            return "Updating folders…"
        case .feeds:
            return "Updating feeds…"
        case .articles(let update):
            if update.isEmpty {
                return "Updating articles…"
            }
            return "Updating \(update)…"
        case .unread:
            return "Updating unread articles…"
        case .starred:
            return "Updating starred articles…"
        case .favicons:
            return "Updating favicons…"
        }
    }
}

struct SyncRequests {
    let foldersRequest: URLRequest
    let feedsRequest: URLRequest
    let itemsRequest: URLRequest
    let unreadItemsRequest: URLRequest
    let starredItemsRequest: URLRequest
}

@Observable
final class SyncManager {
    @ObservationIgnored @AppStorage(SettingKeys.syncInBackground) private var syncInBackground = false
    @ObservationIgnored @AppStorage(SettingKeys.didSyncInBackground) private var didSyncInBackground = false
    @ObservationIgnored @AppStorage(SettingKeys.keepDuration) private var keepDuration = 0
    @ObservationIgnored @AppStorage(SettingKeys.lastModified) private var lastModified = 0

    var syncState: SyncState = .idle

    private let backgroundActor: NewsModelActor
    private let backgroundSession: URLSession

    private var foldersDTO = FoldersDTO(folders: [FolderDTO]())
    private var feedDTOs = [FeedDTO]()

    init(modelContainer: ModelContainer) {
        self.backgroundActor = NewsModelActor(modelContainer: modelContainer)
        let backgroundSessionConfig = URLSessionConfiguration.background(withIdentifier: Constants.appUrlSessionId)
        backgroundSessionConfig.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: backgroundSessionConfig)
    }

    private func syncRequests() async throws -> SyncRequests {
//        let newestKnownLastModified = await backgroundActor.maxLastModified()
        let foldersRequest = try Router.folders.urlRequest()
        let feedsRequest = try Router.feeds.urlRequest()
        
        let updatedParameters: ParameterDict = ["type": 3,
                                                "lastModified": lastModified,
                                                "id": 0]
        let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)
        let itemsRequest = try updatedItemRouter.urlRequest()
        let unreadParameters: ParameterDict = ["type": 3,
                                               "getRead": false,
                                               "batchSize": -1]
        let unreadRequest = try Router.items(parameters: unreadParameters).urlRequest()

        let starredParameters: ParameterDict = ["type": 2,
                                                "getRead": true,
                                                "batchSize": -1]
        let starredRequest = try Router.items(parameters: starredParameters).urlRequest()

        return SyncRequests(foldersRequest: foldersRequest, feedsRequest: feedsRequest, itemsRequest: itemsRequest, unreadItemsRequest: unreadRequest, starredItemsRequest: starredRequest)
    }

    func backgroundSync() async throws {
        guard syncInBackground == true else {
            return
        }
        try await pruneItems()
        let syncRequests = try await syncRequests()
        let foldersResponse = try await withTaskCancellationHandler {
            try await URLSession.shared.data(for: syncRequests.foldersRequest).0
        } onCancel: {
            let task = backgroundSession.downloadTask(with: syncRequests.foldersRequest)
            task.taskDescription = "folders"
            task.resume()
        }

        let feedsResponse = try await withTaskCancellationHandler {
            try await URLSession.shared.data(for: syncRequests.feedsRequest).0
        } onCancel: {
            let task = backgroundSession.downloadTask(with: syncRequests.feedsRequest)
            task.taskDescription = "feeds"
            task.resume()
        }

        let itemsResponse = try await withTaskCancellationHandler {
            try await URLSession.shared.data(for: syncRequests.itemsRequest).0
        } onCancel: {
            let task = backgroundSession.downloadTask(with: syncRequests.itemsRequest)
            task.taskDescription = "items"
            task.resume()
        }

        if !foldersResponse.isEmpty {
            await parseFolders(data: foldersResponse)
        }

        if !feedsResponse.isEmpty {
            await parseFeeds(data: feedsResponse)
        }

        if !itemsResponse.isEmpty {
            await parseItems(data: itemsResponse)
        }
    }

    func processSessionData() {
        backgroundSession.getAllTasks { [self] tasks in
            for task in tasks {
                if task.state == .suspended || task.state == .canceling { continue }
                // NOTE: It seems the task state is .running when this is called, instead of .completed as one might expect.

                if let dlTask = task as? URLSessionDownloadTask {
                    if let url = dlTask.response?.url {
                        if let data = try? Data(contentsOf: url) {
                            switch dlTask.taskDescription {
                            case "folders":
                                Task {
                                    await parseFolders(data: data)
                                }
                            case "feeds":
                                Task {
                                    await parseFeeds(data: data)
                                }
                            case "items":
                                Task {
                                    await parseItems(data: data)
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
            Task { @MainActor in
                didSyncInBackground = true
            }
        }
    }

    func sync() async throws -> NewsStatusDTO? {
        syncState = .started
        let hasItems = await backgroundActor.hasItems()
        let currentStatus = try await newsStatus()
        if hasItems || lastModified == 0 {
            try await repeatSync()
        } else {
            try await initialSync()
            if !hasItems {
                syncState = .favicons
                await getFavIcons()
            }
            syncState = .idle
        }
        WidgetCenter.shared.reloadAllTimelines()
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
        let syncRequests = try await syncRequests()

        let results = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var results = [Int: Data]()

            group.addTask {
                return (1, try await URLSession.shared.data (for: syncRequests.foldersRequest).0)
            }
            group.addTask {
                return (2, try await URLSession.shared.data (for: syncRequests.feedsRequest).0)
            }
            group.addTask {
                return (3, try await URLSession.shared.data (for: syncRequests.starredItemsRequest).0)
            }
            group.addTask {
                return (4, try await URLSession.shared.data (for: syncRequests.unreadItemsRequest).0)
            }

            for try await (index, result) in group {
                results[index] = result
            }

            return results
        }

        if let foldersData = results[1] as Data?, !foldersData.isEmpty {
            syncState = .folders
            await parseFolders(data: foldersData)
        }
        if let feedsData = results[2] as Data?, !feedsData.isEmpty {
            syncState = .feeds
            await parseFeeds(data: feedsData)
        }
        if let starredData = results[3] as Data?, !starredData.isEmpty {
            syncState = .starred
            await parseItems(data: starredData)
        }
        if let unreadData = results[4] as Data?, !unreadData.isEmpty {
            syncState = .unread
            await parseItems(data: unreadData)
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
        let identifiers = try await backgroundActor.allModelIds(FetchDescriptor<Read>())
        for identifier in identifiers {
            if let itemId = try await backgroundActor.fetchItemId(by: identifier) {
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
                    try await backgroundActor.delete(model: Read.self)
                default:
                    break
                }
            }
        }

        var localUnreadIds = [Int64]()
        let unreadIdentifiers = try await backgroundActor.allModelIds(FetchDescriptor<Unread>())
        for identifier in unreadIdentifiers {
            if let itemId = try await backgroundActor.fetchItemId(by: identifier) {
                localUnreadIds.append(itemId)
            }
        }

        if !localUnreadIds.isEmpty {
            let unreadParameters = ["itemIds": localUnreadIds]
            let unreadRouter = Router.itemsUnread(parameters: unreadParameters)
            async let (_, unreadResponse) = URLSession.shared.data(for: unreadRouter.urlRequest(), delegate: nil)
            let unreadItemsResponse = try await unreadResponse
            if let httpUnreadResponse = unreadItemsResponse as? HTTPURLResponse {
                switch httpUnreadResponse.statusCode {
                case 200:
                    try await backgroundActor.delete(model: Unread.self)
                default:
                    break
                }
            }
        }

        var localStarredIds = [Int64]()
        let starredIdentifiers = try await backgroundActor.allModelIds(FetchDescriptor<Starred>())
        for identifier in starredIdentifiers {
            if let itemId = try await backgroundActor.fetchItemId(by: identifier) {
                localStarredIds.append(itemId)
            }
        }

        if !localStarredIds.isEmpty {
            let starredParameters = ["itemIds": localStarredIds]
            let starredRouter = Router.itemsStarred(parameters: starredParameters)
            async let (_, starredResponse) = URLSession.shared.data(for: starredRouter.urlRequest(), delegate: nil)
            let starredItemsResponse = try await starredResponse
            if let httpStarredResponse = starredItemsResponse as? HTTPURLResponse {
                switch httpStarredResponse.statusCode {
                case 200:
                    try await backgroundActor.delete(model: Starred.self)
                default:
                    break
                }
            }
        }

        var localUnstarredIds = [Int64]()
        let unStarredIdentifiers = try await backgroundActor.allModelIds(FetchDescriptor<Unstarred>())
        for identifier in unStarredIdentifiers {
            if let itemId = try await backgroundActor.fetchItemId(by: identifier) {
                localUnstarredIds.append(itemId)
            }
        }

        if !localUnstarredIds.isEmpty {
            let unstarredParameters = ["itemIds": localUnstarredIds]
            let unstarredRouter = Router.itemsStarred(parameters: unstarredParameters)
            async let (_, unstarredResponse) = URLSession.shared.data(for: unstarredRouter.urlRequest(), delegate: nil)
            let unstarredItemsResponse = try await unstarredResponse
            if let httpUnstarredResponse = unstarredItemsResponse as? HTTPURLResponse {
                switch httpUnstarredResponse.statusCode {
                case 200:
                    try await backgroundActor.delete(model: Unstarred.self)
                default:
                    break
                }
            }
        }
        let syncRequests = try await syncRequests()

        let results = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var results = [Int: Data]()

            group.addTask { [self] in
                try await pruneItems()
                return (0, Data())
            }
            group.addTask {
                return (1, try await URLSession.shared.data (for: syncRequests.foldersRequest).0)
            }
            group.addTask {
                return (2, try await URLSession.shared.data (for: syncRequests.feedsRequest).0)
            }
            group.addTask {
                return (3, try await URLSession.shared.data (for: syncRequests.itemsRequest).0)
            }

            for try await (index, result) in group {
                results[index] = result
            }

            return results
        }

        if let foldersData = results[1] as Data?, !foldersData.isEmpty {
            syncState = .folders
            await parseFolders(data: foldersData)
        }
        if let feedsData = results[2] as Data?, !feedsData.isEmpty {
            syncState = .feeds
            await parseFeeds(data: feedsData)
        }
        if let itemsData = results[3] as Data?, !itemsData.isEmpty {
            syncState = .articles(update: "")
            await parseItems(data: itemsData)
        }
    }

    private func parseFolders(data: Data) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FoldersDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        self.foldersDTO = decodedResponse
        let folderIds = decodedResponse.folders.map( { $0.id } )
        do {
            try await backgroundActor.pruneFolders(serverFolderIds: folderIds)
        } catch {
            //
        }
    }

    private func parseFeeds(data: Data) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FeedsDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        self.feedDTOs = decodedResponse.feeds
        let allNode = Node(id: Constants.allNodeGuid, type: .all, title: "All Articles", pinned: 1)
        await backgroundActor.insert(allNode)
        let unreadNode = Node(id: Constants.unreadNodeGuid, type: .unread, title: "Unread Articles", pinned: 1)
        await backgroundActor.insert(unreadNode)
        let starredNode = Node(id: Constants.starNodeGuid, type: .starred, title: "Starred Articles", pinned: 1)
        await backgroundActor.insert(starredNode)
        for folderDTO in foldersDTO.folders {
            var feeds = [NodeDTO]()
            let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == folderDTO.id })
            for feedDTO in feedDTOs  {
                let type = NodeType.feed(id: feedDTO.id)
                let feedNodeDTO = NodeDTO(id: type.description, errorCount: feedDTO.updateErrorCount, isExpanded: false, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: nil, pinned: feedDTO.pinned ? 1 : 0, favIcon: nil, children: nil)
                feeds.append(feedNodeDTO)
                await backgroundActor.insertFeed(feedDTO: feedDTO)
            }
            var localErrorCount: Int64 = 0
            let feedsWithUpdateErrorCount = feeds.filter { $0.errorCount > 0 }
            if !feedsWithUpdateErrorCount.isEmpty {
                localErrorCount = 1
            }
            let type = NodeType.folder(id: folderDTO.id)
            let folderNodeDTO = NodeDTO(id: type.description, errorCount: localErrorCount, isExpanded: folderDTO.opened, type: type, title: folderDTO.name, favIconURL: nil, pinned: 1, favIcon: nil, children: feeds)
            await backgroundActor.insertNode(nodeDTO: folderNodeDTO)
            let itemToStore = Folder(item: folderDTO)
            await backgroundActor.insert(itemToStore)
        }
        let feedDTOs = decodedResponse.feeds.filter( { $0.folderId == nil })
        for feedDTO in feedDTOs {
            let type = NodeType.feed(id: feedDTO.id)
            let feedNodeDTO = NodeDTO(id: type.description, errorCount: feedDTO.updateErrorCount, isExpanded: false, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: nil, pinned: feedDTO.pinned ? 1 : 0, favIcon: nil, children: nil)
            await backgroundActor.insertFeed(feedDTO: feedDTO)
            await backgroundActor.insertNode(nodeDTO: feedNodeDTO)
        }
        let feedIds = decodedResponse.feeds.map( { $0.id } )
        Task {
            do {
                try await backgroundActor.pruneFeeds(serverFeedIds: feedIds)
            } catch {
                //
            }
        }
        try? await backgroundActor.save()
    }

    private func parseItems(data: Data) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(ItemsDTO.self, from: data) else {
            return
        }

        let incomingItems = decodedResponse.items
        let incomingIds = Set(incomingItems.map(\.id))
        let incomingLastModified = incomingItems.compactMap {
            return Int($0.lastModified.timeIntervalSince1970)
        }
        if !incomingLastModified.isEmpty {
            lastModified = incomingLastModified.reduce(0, max)
        }

        do {
            let existingMediaById = try await backgroundActor.existingMediaMap(for: incomingIds)
            let totalCount = incomingItems.count
            var counter = 0
            for eachItem in incomingItems {
                counter += 1
                await MainActor.run {
                    self.syncState = .articles(update: "\(counter) of \(totalCount)")
                }

                await backgroundActor.buildAndInsert(from: eachItem, existing: existingMediaById[eachItem.id], retrieveWidgetImage: (counter < 10) && (eachItem.unread == true))

                if counter % 15 == 0 {
                    do {
                        try await backgroundActor.save()
                    } catch {
                        syncState = .idle
                    }
                    await MainActor.run {
                        NotificationCenter.default.post(name: .articlesUpdated, object: nil)
                    }
                }
            }

            do {
                try await backgroundActor.save()
                let unreadCount = await backgroundActor.unreadCount()
                await MainActor.run {
                    UNUserNotificationCenter.current().setBadgeCount(unreadCount)
                }
                syncState = .idle
            } catch {
                syncState = .idle
            }
        } catch {
            //
        }
    }

    private func pruneItems() async throws {
        do {
            if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * keepDuration), to: Date()) {
                print("limitDate: \(limitDate) date: \(Date())")
                try await backgroundActor.delete(model: Item.self, where: #Predicate { $0.unread == false && $0.starred == false && $0.lastModified < limitDate } )
            }
        } catch {
            throw DatabaseError.itemsFailedImport
        }
    }

    private func getFavIcons() async {
        for feedDTO in feedDTOs {
            let validSchemas = ["http", "https", "file"]
            var itemImageUrl: URL?
            if let faviconLink = feedDTO.faviconLink,
               let url = URL(string: faviconLink),
               let scheme = url.scheme,
               validSchemas.contains(scheme) {
                itemImageUrl = url
            } else {
                if let feedUrl = URL(string: feedDTO.link ?? "data:null"),
                   let host = feedUrl.host,
                   let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                    itemImageUrl = url
                }
            }

            var imageData: Data?
            if let itemImageUrl {
                do {
                    let (data, _) = try await URLSession.shared.data(from: itemImageUrl)
                    imageData = data
                } catch {
                    print("Error fetching data: \(error)")
                }
            }

            if let imageData {
                let favIconDTO = FavIconDTO(id: feedDTO.id, url: itemImageUrl, icon: imageData)
                await backgroundActor.insertFavIcon(itemDTO: favIconDTO)
            }
        }
        do {
            try await backgroundActor.save()
        } catch { }
    }

}
