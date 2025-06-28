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
    let databaseActor: NewsDataModelActor
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

    init(databaseActor: NewsDataModelActor) {
        self.databaseActor = databaseActor
    }

    private func updateUnreadItemIds() async  {
        Task {
            var unreadFetchDescriptor = FetchDescriptor<Item>()
            switch currentNodeType {
            case .empty:
                unreadFetchDescriptor.predicate = #Predicate<Item>{ _ in false }
            case .all:
                unreadFetchDescriptor.predicate = #Predicate<Item>{ $0.unread }
            case .starred:
                unreadFetchDescriptor.predicate = #Predicate<Item>{ _ in false }
            case .folder(id:  let id):
                let feedIds = await databaseActor.feedIdsInFolder(folder: id) ?? []
                unreadFetchDescriptor.predicate = #Predicate<Item>{ feedIds.contains($0.feedId) && $0.unread }
            case .feed(id: let id):
                unreadFetchDescriptor.predicate = #Predicate<Item>{  $0.feedId == id && $0.unread }
            }
            unreadItemIds = try await databaseActor.fetchUnreadIds(descriptor: unreadFetchDescriptor)
        }
    }

    func delete(_ node: Node) async throws {
        switch node.type {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            if let feedIds = await databaseActor.feedIdsInFolder(folder: id) {
                let deleteRouter = Router.deleteFolder(id: Int(id))
                do {
                    let (_, deleteResponse) = try await session.data(for: deleteRouter.urlRequest(), delegate: nil)
                    if let httpResponse = deleteResponse as? HTTPURLResponse {
                        print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                        switch httpResponse.statusCode {
                        case 200, 404: // 404 = Folder does not exist but the app thinks it does, so delete locally
                            for feedId in feedIds {
                                try await databaseActor.deleteItems(with: feedId)
                            }
                            try await databaseActor.deleteNode(id: node.id)
                            try await databaseActor.deleteFolder(id: id)
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
                        try await databaseActor.deleteItems(with: Int64(id))
                        try await databaseActor.deleteNode(id: node.id)
                        try await databaseActor.deleteFeed(id: Int64(id))
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
                        let type = NodeType.feed(id: feedDTO.id)
                        let feedNode = Node(id: type.description, type: type, title: feedDTO.title ?? "Untitled Feed", favIconURL: nil, children: [], errorCount: 0)
                        await databaseActor.insert(feedNode)
                        let itemToStore = await Feed(item: feedDTO)
                        await databaseActor.insert(itemToStore)
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
                    let type = NodeType.folder(id: folderDTO.id)
                    let folderNode = Node(id: type.description, type: type, title: folderDTO.name, isExpanded: folderDTO.opened, favIconURL: nil, children: [], errorCount: 0)
                    await databaseActor.insert(folderNode)
                    let itemToStore = Folder(item: folderDTO)
                    await databaseActor.insert(itemToStore)
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
                for eachItem in decodedResponse.items {
                    let itemToStore = await Item(item: eachItem)
                    await databaseActor.insert(itemToStore)
                }
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }

    @MainActor
    func markCurrentItemsRead() async {
        var internalUnreadItemIds = [Int64]()
        do {
            for unreadItemId in unreadItemIds {
                if let itemId = try await databaseActor.update(unreadItemId, keypath: \.unread, to: false) {
                    internalUnreadItemIds.append(itemId)
                }
            }
            try await markRead(itemIds: internalUnreadItemIds, unread: false)
        } catch {

        }
    }

    @MainActor
    func markItemsRead(items: [Item]) {
        guard !items.isEmpty else {
            return
        }
        for item in items {
            item.unread = false
        }
        Task {
            try await databaseActor.save()
            try await self.markRead(items: items, unread: false)
        }
    }

    @MainActor
    func toggleCurrentItemRead() {
        if let currentItem = currentItem {
            toggleItemRead(item: currentItem)
        }
    }

    @MainActor
    func toggleItemRead(item: Item) {
        Task {
            do {
                item.unread.toggle()
                try await databaseActor.save()
                try await self.markRead(items: [item], unread: !item.unread)
            } catch {
                //
            }
        }
    }

    func markRead(items: [Item], unread: Bool) async throws {
        guard !items.isEmpty else {
            return
        }
        let itemIds = items.map( { $0.id } )
        try await markRead(itemIds: itemIds, unread: unread)
    }

    func markRead(itemIds: [Int64], unread: Bool) async throws {
        guard !itemIds.isEmpty else {
            return
        }
        do {
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
                        try await databaseActor.delete(model: Unread.self)
                    } else {
                        try await databaseActor.delete(model: Read.self)
                    }
                default:
                    if unread {
                        for itemId in itemIds {
                            await databaseActor.insert(Read(itemId: itemId))
                        }
                    } else {
                        for itemId in itemIds {
                            await databaseActor.insert(Unread(itemId: itemId))
                        }
                    }
                }
                try await databaseActor.save()
            }
            await updateUnreadItemIds()
            let unreadCount = try await databaseActor.fetchCount(predicate: #Predicate<Item> { $0.unread == true } )
            await MainActor.run {
                UNUserNotificationCenter.current().setBadgeCount(unreadCount)
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    func markCurrentItemStarred() async throws {
        if let currentItem = currentItem {
            try await markStarred(item: currentItem, starred: !currentItem.starred)
        }
    }

    func markStarred(item: Item, starred: Bool) async throws {
        do {
            item.starred = starred
            try await databaseActor.save()

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
                        try await databaseActor.delete(model: Unstarred.self)
                    } else {
                        try await databaseActor.delete(model: Starred.self)
                    }
                default:
                    let itemDataId = try JSONEncoder().encode(item.persistentModelID)
                    if starred {
                        await databaseActor.insert(Starred(itemIdData: itemDataId))
                    } else {
                        await databaseActor.insert(Unstarred(itemIdData: itemDataId))
                    }
                }
                try await databaseActor.save()
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
        return await databaseActor.folderName(id: id) ?? Constants.untitledFolderName
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
        return await databaseActor.feedPrefersWeb(id: id)
    }

    func resetDataBase() async throws {
        do {
            try await databaseActor.delete(model: Node.self)
            try await databaseActor.delete(model: Feeds.self)
            try await databaseActor.delete(model: Feed.self)
            try await databaseActor.delete(model: Folder.self)
            try await databaseActor.delete(model: Item.self)
            try await databaseActor.delete(model: Read.self)
            try await databaseActor.delete(model: Unread.self)
            try await databaseActor.delete(model: Starred.self)
            try await databaseActor.delete(model: Unstarred.self)
        } catch {
            throw DatabaseError.generic(message: "Failed to clear the local database")
        }
    }

}
