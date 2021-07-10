//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData
import Foundation
import SwiftUI

final class Node<Value>: Identifiable, ObservableObject {
    @Published var value: Value
    private(set) var children: [Node]?

    init(_ value: Value) {
        self.value = value
    }

    init(_ value: Value, children: [Node]) {
        self.value = value
        self.children = children
    }

    init(_ value: Value, @NodeBuilder builder: () -> [Node]) {
        self.value = value
        self.children = builder()
    }

    func add(child: Node) {
        if children == nil {
            children = []
        }
        children?.append(child)
    }
}

extension Node: Equatable where Value: Equatable {
    static func ==(lhs: Node, rhs: Node) -> Bool {
        lhs.value == rhs.value && lhs.children == rhs.children
    }
}

extension Node: Hashable where Value: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(children)
    }
}

extension Node where Value: Equatable {
    func find(_ value: Value) -> Node? {
        if self.value == value {
            return self
        }

        if let children = children {
            for child in children {
                if let match = child.find(value) {
                    return match
                }
            }
        }
        
        return nil
    }
}

@resultBuilder
struct NodeBuilder {
    static func buildBlock<Value>(_ children: Node<Value>...) -> [Node<Value>] {
        children
    }
}

class FeedTreeModel: NSObject, ObservableObject {
    @Published var feedTree = Node(TreeNode(isLeaf: false, items: [], sortId: -1, basePredicate: NSPredicate(value: true), nodeType: .all))
    let objectWillChange = ObservableObjectPublisher()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        cancellables.insert(NotificationCenter.default
                                .publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext)
                                .sink(receiveValue: { [weak self] notification in
            self?.updateCounts()
        }))

        update()
    }
    

    func updateCounts() {
        if let children = feedTree.children {
            for node in children {
                node.value.updateCount()
            }
        }
    }

    func update() {
        feedTree.add(child: buildAllItemsNode())
        feedTree.add(child: buildStarredItemsNode())

        if let folders = CDFolder.all() {
            for folder in folders {
                feedTree.add(child: buildFolderNode(folder: folder))
            }
        }
        if let feeds = CDFeed.inFolder(folder: 0) {
            for feed in feeds {
                feedTree.add(child: buildFeedNode(feed: feed))
            }
        }
        updateCounts()
    }

    private func buildAllItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .all)
        let items = CDItem.items(nodeType: .all)
        let itemsNode = TreeNode(isLeaf: true,
                                 items: items ?? [],
                                 title: "All Articles",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(),
                                 sortId: 0,
                                 basePredicate: NSPredicate(value: true),
                                 nodeType: .all)
        return Node(itemsNode)
    }

    private func buildStarredItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .starred)
        let items = CDItem.items(nodeType: .starred)
        let itemsNode = TreeNode(isLeaf: true,
                                 items: items ?? [],
                                 title: "Starred Articles",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(feed: nil, isFolder: false, isStarred: true),
                                 sortId: 0,
                                 basePredicate: NSPredicate(format: "starred == true"),
                                 nodeType: .starred)
        return Node(itemsNode)
    }

    private func buildFolderNode(folder: CDFolder) -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .folder(id: folder.id))
        let items = CDItem.items(nodeType: .folder(id: folder.id))
        
        var basePredicate: NSPredicate {
            if let feedIds = CDFeed.idsInFolder(folder: folder.id) {
                return NSPredicate(format: "feedId IN %@", feedIds)
            }
            return NSPredicate(value: false)
        }
        
        let folderNode = Node(TreeNode(isLeaf: false,
                                       items: items ?? [],
                                       title: folder.name ?? "Untitled Folder",
                                       unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                       faviconImage: FavImage(feed: nil, isFolder: true),
                                       sortId: Int(folder.id) + 100,
                                       basePredicate: basePredicate,
                                       nodeType: .folder(id: folder.id)))
        
        if let feeds = CDFeed.inFolder(folder: folder.id) {
            for feed in feeds {
                folderNode.add(child: buildFeedNode(feed: feed))
            }
        }
        return folderNode
    }

    private func buildFeedNode(feed: CDFeed) -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .feed(id: feed.id))
        let items = CDItem.items(nodeType: .feed(id: feed.id))

        let itemsNode = TreeNode(isLeaf: true,
                                 items: items ?? [],
                                 title: feed.title ?? "Untitled Feed",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(feed: feed),
                                 sortId: Int(feed.id) + 1000,
                                 basePredicate: NSPredicate(format: "feedId == %d", feed.id),
                                 nodeType: .feed(id: feed.id))
        return Node(itemsNode)
    }

}
