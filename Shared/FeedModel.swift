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
    let backgroundModelActor: BackgroundModelActor
    var webImporter: WebImporter
    var itemPruner: ItemPruner
    let session = ServerStatus.shared.session

//    var currentItems = [Item]()
    var currentItem: Item? = nil
    var currentNode: NodeStruct? = nil
    var currentItemID: PersistentIdentifier? = nil
//    @MainActor var unreadCount = 0
    var isSyncing = false

    init(backgroundModelActor: BackgroundModelActor) {
        self.backgroundModelActor = backgroundModelActor
//        backgroundModelActor.modelContext.autosaveEnabled = false
//        Task {
            self.webImporter = WebImporter(backgroundModelActor: backgroundModelActor)
            self.itemPruner = ItemPruner(backgroundModelActor: backgroundModelActor)
//            await updateUnreadCount()
//        }
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

    func delete(_ node: NodeStruct) {
        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            Task {
                do {
                  try await deleteFolder(Int(id))
                    if let feedIds = await backgroundModelActor.feedIdsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await backgroundModelActor.deleteItems(with: feedId)
                            try await backgroundModelActor.deleteFolder(id: feedId)
                        }
                    }
                    try await backgroundModelActor.deleteFolder(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            Task {
                do {
                    try await deleteFeed(Int(id))
                    try await backgroundModelActor.deleteItems(with: id)
                    try await backgroundModelActor.deleteFeed(id: id)
                } catch {
                    //
                }
            }
        }
    }

    @MainActor
    func markCurrentNodeRead() {
        Task {
            if let currentNode {
                var predicate = #Predicate<Item> { _ in return false }
                switch currentNode.nodeType {
                case .empty:
                    break
                case .all:
                    predicate = #Predicate<Item> { $0.unread == true }
                case .starred:
                    predicate = #Predicate<Item> { $0.starred == true }

                case .feed(let id):
                    predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
                case .folder(let id):
                    if let feedIds = await backgroundModelActor.feedIdsInFolder(folder: id) {
                        predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
                    }
                }
                let descriptor = FetchDescriptor<Item>(predicate: predicate)
                do {
//                    let items = try await backgroundModelActor.fetchData(predicate: predicate)
//                    markItemsRead(items: items)
//                    unreadCount = 0
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
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
//            updateUnreadCount()
        }
    }

    @MainActor
    func toggleItemRead(item: Item) {
        Task {
            do {
                item.unread.toggle()
                try await backgroundModelActor.save()
                Task {
                    try await self.markRead(items: [item], unread: !item.unread)
//                    updateUnreadCount()
                }
            } catch {
                //
            }
        }
    }

//    @MainActor
//    func updateUnreadCount() {
//        if let currentNode {
//            var predicate = #Predicate<Item> { _ in return false }
//            switch currentNode.nodeType {
//            case .empty:
//                break
//            case .all:
//                predicate = #Predicate<Item> { $0.unread == true }
//            case .starred:
//                predicate = #Predicate<Item> { $0.starred == true }
//
//            case .feed(let id):
//                predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
//            case .folder(let id):
//                if let feedIds = backgroundModelActor.feedIdsInFolder(folder: id) {
//                    predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
//                }
//            }
//            let descriptor = FetchDescriptor<Item>(predicate: predicate)
//            do {
//                unreadCount = try backgroundModelActor.fetchCount(predicate: predicate)
//            } catch let error as NSError {
//                print("Could not fetch \(error), \(error.userInfo)")
//            }
//        }
//    }

}
