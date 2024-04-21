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
class FeedModel {
    let modelContext: ModelContext
    let itemImporter: ItemImporter
    let session = ServerStatus.shared.session

    var nodes = [Node]()
    var currentNode: Node?
    var currentItems = [Item]()
    var currentItem: Item? = nil
    var currentNodeID: Node.ID? = nil
    var currentItemID: PersistentIdentifier? = nil
    var isSyncing = false

    private var isInInit = true

    var folders = [Folder]() {
        didSet {
            if !isInInit {
                update()
            }
        }
    }

    var feeds = [Feed]()  {
        didSet {
            if !isInInit {
                update()
            }
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.modelContext.autosaveEnabled = false
        self.itemImporter = ItemImporter(modelContext: modelContext)
        nodes.append(Node(.all, id: Constants.allNodeGuid, feedModel: self))
        nodes.append(Node(.starred, id: Constants.starNodeGuid, feedModel: self))
        update()
        isInInit = false
    }

    private func update() {
        var folderNodes = [Node]()
        var feedNodes = [Node]()

        if let folders = modelContext.allFolders() {
            for folder in folders {
                folderNodes.append(Node(folder: folder, feedModel: self))
            }
        }

        if let feeds = modelContext.feedsInFolder(folder: 0) {
            for feed in feeds {
                feedNodes.append(Node(feed: feed, feedModel: self))
            }
        }

        let firstFolderIndex = 2
        if let lastFolderIndex = nodes.lastIndex(where: { $0.id.hasPrefix("folder") }) {
            self.nodes.replaceSubrange(firstFolderIndex...lastFolderIndex, with: folderNodes)
        } else {
            self.nodes.append(contentsOf: folderNodes)
        }

        if let firstFeedIndex = nodes.firstIndex(where: { $0.id.hasPrefix("feed") }),
           let lastFeedIndex = nodes.lastIndex(where: { $0.id.hasPrefix("feed") }) {
            self.nodes.replaceSubrange(firstFeedIndex...lastFeedIndex, with: feedNodes)
        } else {
            self.nodes.append(contentsOf: feedNodes)
        }
    }

    func selectPreviousItem() {
        if let currentIndex = currentItems.first(where: { $0.persistentModelID == currentItemID }) {
            currentItemID = currentItems.element(before: currentIndex)?.persistentModelID
        }
    }

    func selectNextItem() {
        if let currentIndex = currentItems.first(where: { $0.persistentModelID == currentItemID }) {
            currentItemID = currentItems.element(after: currentIndex)?.persistentModelID
        }
    }

    func delete(_ node: Node) {
        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            Task {
                do {
                  try await deleteFolder(Int(id))
                    if let feedIds = modelContext.feedIdsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await modelContext.deleteItems(with: feedId)
                            try await modelContext.deleteFolder(id: feedId)
                        }
                    }
                    try await modelContext.deleteFolder(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            Task {
                do {
                    try await deleteFeed(Int(id))
                    try await modelContext.deleteItems(with: id)
                    try await modelContext.deleteFeed(id: id)
                } catch {
                    //
                }
            }
        }
    }

    func node(id: Node.ID) -> Node {
        if let node = nodes.first(where: { $0.id == id } ) {
            return node
        } else {
            let folderNodes = nodes.filter( { !($0.children?.isEmpty ?? false) })
            for folderNode in folderNodes {
                if let node = folderNode.children?.first(where: { $0.id == id } ) {
                    return node
                }
            }
            return Node(feedModel: self)
        }
    }

    func markItemsRead(items: [Item]) {
        guard !items.isEmpty else {
            return
        }
        for item in items {
            item.unread = false
        }
        Task.detached {
            try await self.markRead(items: items, unread: false)
        }
    }

    func toggleItemRead(item: Item) {
        do {
            item.unread.toggle()
            try modelContext.save()
            Task {
                try await self.markRead(items: [item], unread: !item.unread)
            }
        } catch {
            //
        }
    }

}
