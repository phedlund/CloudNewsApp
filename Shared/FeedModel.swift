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

    func delete(_ node: Node) {
        switch node.type {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            Task {
                do {
                  try await deleteFolder(Int(id))
                    if let feedIds = await databaseActor.feedIdsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await databaseActor.deleteItems(with: feedId)
                            try await databaseActor.deleteFolder(id: feedId)
                        }
                    }
                    try await databaseActor.deleteFolder(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            Task {
                do {
                    try await deleteFeed(Int(id))
                    try await databaseActor.deleteItems(with: id)
                    try await databaseActor.deleteFeed(id: id)
                } catch {
                    //
                }
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
