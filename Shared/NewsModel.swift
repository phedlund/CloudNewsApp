//
//  FeedModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Foundation
import Observation
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

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
    var unreadCounts = [NodeType: Int]()

    var itemNavigationPath = NavigationPath()

    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
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
                    let itemToStore = await Item(item: eachItem)
                    let itemToInsert = Item(author: itemToStore.author,
                                            body: itemToStore.body,
                                            contentHash: itemToStore.contentHash,
                                            displayBody: itemToStore.displayBody,
                                            displayTitle: itemToStore.displayTitle,
                                            dateFeedAuthor: itemToStore.dateFeedAuthor,
                                            enclosureLink: itemToStore.enclosureLink,
                                            enclosureMime: itemToStore.enclosureMime,
                                            feedId: itemToStore.feedId,
                                            fingerprint: itemToStore.fingerprint,
                                            guid: itemToStore.guid,
                                            guidHash: itemToStore.guidHash,
                                            id: itemToStore.id,
                                            lastModified: itemToStore.lastModified,
                                            mediaThumbnail: itemToStore.mediaThumbnail,
                                            mediaDescription: itemToStore.mediaDescription,
                                            pubDate: itemToStore.pubDate,
                                            rtl: itemToStore.rtl,
                                            starred: itemToStore.starred,
                                            title: itemToStore.title,
                                            unread: itemToStore.unread,
                                            updatedDate: itemToStore.updatedDate,
                                            url: itemToStore.url,
                                            thumbnailURL: itemToStore.thumbnailURL,
                                            image: itemToStore.image,
                                            thumbnail: itemToStore.thumbnail)
                    await backgroundActor.insert(itemToInsert)
                }
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }

    func markCurrentItemsRead() async {
        var internalUnreadItemIds = [Int64]()
        let backgroundActor = NewsModelActor(modelContainer: modelContainer)
        do {
            for unreadItemId in unreadItemIds {
                if let itemId = try await backgroundActor.update(unreadItemId, keypath: \.unread, to: false) {
                    internalUnreadItemIds.append(itemId)
                }
            }
            try await backgroundActor.save()
            try await markRead(itemIds: internalUnreadItemIds, unread: false)
        } catch {

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
                try await backgroundActor.save()
            }
            await updateUnreadItemIds()
            let unreadCount = try await backgroundActor.fetchCount(predicate: #Predicate<Item> { $0.unread == true } )
            await MainActor.run {
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
            try await self.markStarred(item: item, starred: !currentState)
        } catch {

        }
    }

    private func markStarred(item: Item, starred: Bool) async throws {
        do {
            let parameters: ParameterDict = ["itemIds": [item.id]]
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
                    let itemDataId = try JSONEncoder().encode(item.persistentModelID)
                    if starred {
                        await backgroundActor.insert(Starred(itemIdData: itemDataId))
                    } else {
                        await backgroundActor.insert(Unstarred(itemIdData: itemDataId))
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
