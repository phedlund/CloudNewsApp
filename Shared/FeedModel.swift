//
//  FeedModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Foundation
import Observation
import SwiftData

@Observable
class FeedModel: @unchecked Sendable {
    let databaseActor: NewsDataModelActor
    let session = ServerStatus.shared.session

    var currentNode: Node? = nil

    init(databaseActor: NewsDataModelActor) {
        self.databaseActor = databaseActor
    }

//    func selectPreviousItem() {
//        if let currentIndex = currentItems.first(where: { $0.persistentModelID == currentItemID }) {
//            currentItemID = currentItems.element(before: currentIndex)?.persistentModelID
//        }
//    }
//
//    func selectNextItem() {
//        if let currentIndex = currentItems.first(where: { $0.persistentModelID == currentItemID }) {
//            currentItemID = currentItems.element(after: currentIndex)?.persistentModelID
//        }
//    }

    func delete(_ node: Node, feeds: [Feed]? = nil) async throws {
        switch node.type {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            let feedIds = feeds?.compactMap(\.id) ?? []
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
            try await self.markRead(items: items, unread: false)
        }
    }

    @MainActor
    func toggleItemRead(item: Item) {
        Task {
            do {
                item.unread.toggle()
                try await databaseActor.save()
                Task {
                    try await self.markRead(items: [item], unread: !item.unread)
                }
            } catch {
                //
            }
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
                        let itemToStore = Feed(item: feedDTO)
                        await databaseActor.insert(itemToStore)
                        try await addItems(feed: feedDTO.id)
                    }
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
            default:
                break
            }
        }
    }

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
                        try await databaseActor.delete(model: Unread.self)
                        try await databaseActor.save()
                    } else {
                        try await databaseActor.delete(model: Read.self)
                        try await databaseActor.save()
                    }
                default:
                    if unread {
                        for itemId in itemIds {
                            await databaseActor.insert(Read(itemId: itemId))
                        }
                        try await databaseActor.save()
                    } else {
                        for itemId in itemIds {
                            await databaseActor.insert(Unread(itemId: itemId))
                        }
                        try await databaseActor.save()
                    }
                }
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
