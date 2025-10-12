//
//  FeedModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Foundation
import SwiftData
import SwiftSoup
import SwiftUI
import UserNotifications
import WidgetKit


public enum FavIconService {
    case feed
    case homePage
    case duckDuckGo
    case google
}

@Observable
class NewsModel: @unchecked Sendable {
    let session = ServerStatus.shared.session

    var currentNodeType: NodeType = .empty {
        didSet {
            if oldValue != currentNodeType {
                Task {
                    await updateUnreadItemIds()
                }
            }
        }
    }

    var currentItem: Item? = nil
    var navigationItemId: Int64 = 0
    var unreadItemIds = [PersistentIdentifier]()
    private(set) var unreadCounts = [String: Int]()

    var itemNavigationPath = NavigationPath()

    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    func refreshUnreadCount(for node: Node) async {
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)

        var predicate: Predicate<Item>
        switch node.type {
        case .empty, .all:
            predicate = #Predicate<Item> { _ in false }
        case .unread:
            predicate = #Predicate<Item> { $0.unread == true }
        case .starred:
            predicate = #Predicate<Item> { $0.starred == true }
        case .feed(let id):
            predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
        case .folder(let id):
            let feedIds = await backgroundActor.feedIdsInFolder(folder: id) ?? []
            predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
        }

        let descriptor = FetchDescriptor<Item>(predicate: predicate)
        if let count = try? await backgroundActor.fetchCount(descriptor) {
            unreadCounts[node.id] = count
        }
    }

    // Refresh all counts
    @MainActor
    func refreshAllUnreadCounts(nodes: [Node]) async {
        for node in nodes {
            await refreshUnreadCount(for: node)
        }
    }

    // Invalidate all counts (call after batch operations)
    func invalidateUnreadCounts() {
        unreadCounts.removeAll()
    }

    func updateUnreadItemIds() async  {
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        var unreadFetchDescriptor = FetchDescriptor<Item>()
        switch currentNodeType {
        case .empty:
            unreadFetchDescriptor.predicate = #Predicate<Item>{ _ in false }
        case .all, .unread:
            unreadFetchDescriptor.predicate = #Predicate<Item>{ $0.unread }
        case .starred:
            unreadFetchDescriptor.predicate = #Predicate<Item>{ _ in false }
        case .folder(id:  let id):
            let feedIds = await backgroundActor.feedIdsInFolder(folder: id) ?? []
            unreadFetchDescriptor.predicate = #Predicate<Item>{ feedIds.contains($0.feedId) && $0.unread }
        case .feed(id: let id):
            unreadFetchDescriptor.predicate = #Predicate<Item>{  $0.feedId == id && $0.unread }
        }
        do {
            unreadItemIds = try await backgroundActor.fetchUnreadIds(descriptor: unreadFetchDescriptor)
        } catch {
            unreadItemIds = []
        }
    }

    func delete(_ node: Node) async throws {
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        switch node.type {
        case .empty, .all, .unread, .starred:
            break
        case .folder(let id):
            if let feedIds = await backgroundActor.feedIdsInFolder(folder: id) {
                let deleteRouter = Router.deleteFolder(id: Int(id))
                do {
                    let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
                    if let httpResponse = deleteResponse as? HTTPURLResponse {
                        print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                        switch httpResponse.statusCode {
                        case 200, 404: // 404 = Folder does not exist but the app thinks it does, so delete locally
                            for feedId in feedIds {
                                try await backgroundActor.deleteItems(with: feedId)
                            }
                            try await backgroundActor.deleteNode(id: node.id)
                            try await backgroundActor.deleteFolder(id: id)
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
        case .feed(let id):
            let deleteRouter = Router.deleteFeed(id: Int(id))
            do {
                let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
                if let httpResponse = deleteResponse as? HTTPURLResponse {
                    print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                    switch httpResponse.statusCode {
                    case 200, 404: // 404 = Feed does not exist but the app thinks it does, so delete locally
                        try await backgroundActor.deleteItems(with: Int64(id))
                        try await backgroundActor.deleteNode(id: node.id)
                        try await backgroundActor.deleteFeed(id: Int64(id))
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
        WidgetCenter.shared.reloadAllTimelines()
    }

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
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    guard let decodedResponse = try? decoder.decode(FeedsDTO.self, from: data) else {
                        return
                    }
                    if let feedDTO = decodedResponse.feeds.first {
                        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
                        let type = NodeType.feed(id: feedDTO.id)
                        let feedNode = Node(id: type.description,
                                            type: type,
                                            title: feedDTO.title ?? "Untitled Feed",
                                            children: [],
                                            errorCount: 0)
                        await backgroundActor.insert(feedNode)
                        let feedToInsert = Feed(added: feedDTO.added,
                                                faviconLink: feedDTO.faviconLink,
                                                folderId: feedDTO.folderId,
                                                id: feedDTO.id,
                                                lastUpdateError: feedDTO.lastUpdateError,
                                                link: feedDTO.link,
                                                nextUpdateTime: feedDTO.nextUpdateTime,
                                                ordering: feedDTO.ordering,
                                                pinned: feedDTO.pinned,
                                                title: feedDTO.title,
                                                unreadCount: feedDTO.unreadCount ?? 0,
                                                updateErrorCount: feedDTO.updateErrorCount,
                                                url: feedDTO.url,
                                                items: [])
                        await backgroundActor.insert(feedToInsert)
                        try await addItems(feed: feedDTO.id)
                        try await addFavIcon(feedId: feedDTO.id, faviconLink: feedDTO.faviconLink, link: feedDTO.link, service: .feed)
                    }
                    WidgetCenter.shared.reloadAllTimelines()
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
        let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
        if let httpResponse = response as? HTTPURLResponse {
            print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
            print(String(data: data, encoding: .utf8) ?? "")
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                guard let decodedResponse = try? decoder.decode(FoldersDTO.self, from: data) else {
                    return
                }
                if let folderDTO = decodedResponse.folders.first {
                    let backgroundActor = NewsModelActor(modelContainer: modelContainer)
                    let type = NodeType.folder(id: folderDTO.id)
                    let folderNode = Node(id: type.description, type: type, title: folderDTO.name, isExpanded: folderDTO.opened, children: [], errorCount: 0)
                    await backgroundActor.insert(folderNode)
                    let itemToStore = Folder(item: folderDTO)
                    await backgroundActor.insert(itemToStore)
                }
                WidgetCenter.shared.reloadAllTimelines()
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
    }

    func addItems(feed: Int64) async throws {
        let parameters: ParameterDict = ["batchSize": 200,
                                         "offset": 0,
                                         "type": 0,
                                         "id": feed,
                                         "getRead": true]
        let router = Router.items(parameters: parameters)
        let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
        if let httpResponse = response as? HTTPURLResponse {
            print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
            print(String(data: data, encoding: .utf8) ?? "")
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                guard let decodedResponse = try? decoder.decode(ItemsDTO.self, from: data) else {
                    return
                }
                let backgroundActor = NewsModelActor(modelContainer: modelContainer)
                for eachItem in decodedResponse.items {
                    await backgroundActor.buildAndInsert(from: eachItem, existing: nil)
                }
                try await backgroundActor.save()
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }

    func addFavIcon(feedId: Int64, faviconLink: String?, link: String?, service: FavIconService = .homePage) async throws {
        let validSchemas = ["http", "https", "file"]
        var itemImageUrl: URL?

        switch service {
        case .feed:
            if let faviconLink = faviconLink,
               let url = URL(string: faviconLink),
               let scheme = url.scheme,
               validSchemas.contains(scheme) {
                itemImageUrl = url
            }
        case .homePage:
            if let urlString = link, let url = URL(string: urlString) {
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                if let html = String(data: data, encoding: .utf8) {
                    let doc: Document = try SwiftSoup.parse(html)
                    if let favIconLinkString = try doc.select("link[rel=icon]").first()?.attr("href"),
                       let favIconUrl = URL(string: favIconLinkString, relativeTo: url) {
                        itemImageUrl = favIconUrl
                    }
                }
            }
        case .duckDuckGo:
            if let feedUrl = URL(string: link ?? "data:null"),
               let host = feedUrl.host,
               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                itemImageUrl = url
            }
        case .google:
            if let feedUrl = URL(string: link ?? "data:null"),
               let host = feedUrl.host,
               let url = URL(string: "http://www.google.com/s2/favicons") {
                itemImageUrl = url.appending(queryItems: [URLQueryItem(name: "domain", value: host)])
            }
        }

        var imageData: Data?
        if let itemImageUrl {
            let (data, _) = try await URLSession.shared.data(from: itemImageUrl)
            imageData = data
        }

        if let imageData {
            let favIconDTO = FavIconDTO(id: feedId, url: itemImageUrl, icon: imageData)
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            await backgroundActor.insertFavIcon(itemDTO: favIconDTO)
            try await backgroundActor.save()
        }
    }

    func markCurrentItemsRead() async {
        var internalUnreadItemIds = [Int64]()
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        do {
            for unreadItemId in unreadItemIds {
                // Don't modify main context items here
                if let itemId = try await backgroundActor.update(unreadItemId, keypath: \.unread, to: false) {
                    internalUnreadItemIds.append(itemId)
                }
            }
            try await backgroundActor.save()
            try await markRead(itemIds: internalUnreadItemIds, unread: false)

            // IMPORTANT: Invalidate counts after batch operation
            await MainActor.run {
                invalidateUnreadCounts()
            }
        } catch {
            print("Error marking items read: \(error)")
        }
    }
    
    func markItemsRead(items: [Item]) async {
        guard !items.isEmpty else {
            return
        }
        do {
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            var internalUnreadItemIds = [Int64]()
            for unreadItemId in items.compactMap(\.persistentModelID) {
                if let itemId = try await backgroundActor.update(unreadItemId, keypath: \.unread, to: false) {
                    internalUnreadItemIds.append(itemId)
                }
            }
            for item in items {
                item.unread.toggle()
            }
            try await backgroundActor.save()
            try await self.markRead(itemIds: internalUnreadItemIds, unread: false)
        } catch {
            
        }
    }

    func toggleCurrentItemRead() async {
        if let currentItem = currentItem {
            await toggleItemRead(item: currentItem)
        }
    }

    func toggleItemRead(item: Item) async {
        do {
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            let currentState = item.unread
            var internalUnreadItemIds = [Int64]()
            if let itemId = try await backgroundActor.update(item.persistentModelID, keypath: \.unread, to: !currentState) {
                    internalUnreadItemIds.append(itemId)
                }
            item.unread.toggle()
            try await backgroundActor.save()
            try await self.markRead(itemIds: internalUnreadItemIds, unread: !currentState)
        } catch {

        }
    }

    private func markRead(itemIds: [Int64], unread: Bool) async throws {
        guard !itemIds.isEmpty else {
            return
        }
        do {
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            let parameters: ParameterDict = ["itemIds": itemIds]
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
                        try await backgroundActor.delete(model: Unread.self)
                    } else {
                        try await backgroundActor.delete(model: Read.self)
                    }
                default:
                    if unread {
                        for itemId in itemIds {
                            await backgroundActor.insert(Read(itemId: itemId))
                        }
                    } else {
                        for itemId in itemIds {
                            await backgroundActor.insert(Unread(itemId: itemId))
                        }
                    }
                }
            }
            try await backgroundActor.save()
            await updateUnreadItemIds()

            let unreadCount = await backgroundActor.unreadCount()

            await MainActor.run {
                invalidateUnreadCounts()
                NotificationCenter.default.post(name: .unreadStateDidChange, object: nil)
                UNUserNotificationCenter.current().setBadgeCount(unreadCount)
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func toggleCurrentItemStarred() async throws {
        if let currentItem = currentItem {
            await toggleItemStarred(item: currentItem)
        }
    }

    func toggleItemStarred(item: Item) async {
        do {
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            let currentState = item.starred
            let _ = try await backgroundActor.update(item.persistentModelID, keypath: \.starred, to: !currentState)
            item.starred.toggle()
            try await backgroundActor.save()
            try await self.markStarred(itemIds: [item.id], starred: !currentState)
        } catch {

        }
    }

    private func markStarred(itemIds: [Int64], starred: Bool) async throws {
        do {
            let parameters: ParameterDict = ["itemIds": itemIds]
            var router: Router
            if starred {
                router = Router.itemsStarred(parameters: parameters)
            } else {
                router = Router.itemsUnstarred(parameters: parameters)
            }
            let (data, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                let backgroundActor = NewsModelActor(modelContainer: modelContainer)
                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    if starred {
                        try await backgroundActor.delete(model: Unstarred.self)
                    } else {
                        try await backgroundActor.delete(model: Starred.self)
                    }
                default:
                    if starred {
                        for itemId in itemIds {
                            await backgroundActor.insert(Unstarred(itemId: itemId))
                        }
                    } else {
                        for itemId in itemIds {
                            await backgroundActor.insert(Starred(itemId: itemId))
                        }
                    }
                }
                try await backgroundActor.save()
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func renameFeed(feedId: Int64, to name: String) async throws {
        let renameRouter = Router.renameFeed(id: Int(feedId), newName: name)
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

    func folderName(id: Int64) async -> String {
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        return await backgroundActor.folderName(id: id) ?? Constants.untitledFolderName
    }
    
    func renameFolder(folderId: Int64, to name: String) async throws {
        let renameRouter = Router.renameFolder(id: Int(folderId), newName: name)
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

    func moveFeed(feedId: Int64, to folder: Int64) async throws {
        let moveFeedRouter = Router.moveFeed(id: Int(feedId), folder: Int(folder))
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

    func feedPrefersWeb(id: Int64) async -> Bool {
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        return await backgroundActor.feedPrefersWeb(id: id)
    }

    func resetDataBase() async throws {
        do {
            let backgroundActor = NewsModelActor(modelContainer: modelContainer)
            try await backgroundActor.delete(model: Node.self)
            try await backgroundActor.delete(model: Feeds.self)
            try await backgroundActor.delete(model: Feed.self)
            try await backgroundActor.delete(model: Folder.self)
            try await backgroundActor.delete(model: Item.self)
            try await backgroundActor.delete(model: Read.self)
            try await backgroundActor.delete(model: Unread.self)
            try await backgroundActor.delete(model: Starred.self)
            try await backgroundActor.delete(model: Unstarred.self)
            try await backgroundActor.delete(model: FavIcon.self)
        } catch {
            throw DatabaseError.generic(message: "Failed to clear the local database")
        }
    }

}
