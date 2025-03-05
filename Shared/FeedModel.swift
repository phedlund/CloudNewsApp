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
