//
//  NewsManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018-2022 Peter Hedlund. All rights reserved.
//

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

extension FeedModel {

    @MainActor
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
                    // TODO                    try await feedImporter.importFeeds(from: data)
                    //                    if let newFeed = modelContext.insertedModelsArray.first as? Feed {
                    //                        let parameters: ParameterDict = ["batchSize": 200,
                    //                                                         "offset": 0,
                    //                                                         "type": 0,
                    //                                                         "id": newFeed.id,
                    //                                                         "getRead": NSNumber(value: true)]
                    //                        let router = Router.items(parameters: parameters)
                    //                        try await itemImporter.fetchItems(router.urlRequest())
                    //                    }
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
                    }
                    try await databaseActor.save()
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

    @MainActor
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
                    if starred {
                        await databaseActor.insert(Starred(itemId: item.id))
                    } else {
                        await databaseActor.insert(Unstarred(itemId: item.id))
                    }
                }
                try await databaseActor.save()
            }
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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

}
