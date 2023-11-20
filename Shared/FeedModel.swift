//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import Observation
import SwiftData
import SwiftUI

@Observable
class FeedModel {
    var nodes = [Node]()
    var currentNode = Node()
    var currentItems = [Item]()
    var currentItem: Item? = nil
    var currentNodeID: Node.ID? = nil
    var currentItemID: PersistentIdentifier? = nil

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
    
    init() {
        nodes.append(Node(.all, id: Constants.allNodeGuid))
        nodes.append(Node(.starred, id: Constants.starNodeGuid))
        update()
        isInInit = false
    }

    private func update() {
        var folderNodes = [Node]()
        var feedNodes = [Node]()

        if let folders = Folder.all() {
            for folder in folders {
                folderNodes.append(Node(folder: folder))
            }
        }

        if let feeds = Feed.inFolder(folder: 0) {
            for feed in feeds {
                feedNodes.append(Node(feed: feed))
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
                    try await NewsManager.shared.deleteFolder(Int(id))
                    if let feedIds = Feed.idsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await Item.deleteItems(with: feedId)
                            try await Feed.delete(id: feedId)
                        }
                    }
                    try await Folder.delete(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            Task {
                do {
                    try await NewsManager.shared.deleteFeed(Int(id))
                    try await Item.deleteItems(with: id)
                    try await Feed.delete(id: id)
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
            return Node()
        }
    }
}
