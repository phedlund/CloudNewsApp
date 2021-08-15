//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData

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

class FeedTreeModel: NSObject, ObservableObject {
    @Published var nodeArray = [Node<TreeNode>]()
    let objectWillChange = ObservableObjectPublisher()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        cancellables.insert(NotificationCenter.default
                                .publisher(for: .NSManagedObjectContextDidMergeChangesObjectIDs, object: NewsData.mainThreadContext)
                                .receive(on: DispatchQueue.main)
                                .sink(receiveValue: { [weak self] _ in
            self?.updateCounts()
        }))
        cancellables.insert(NotificationCenter.default
                                .publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext)
                                .receive(on: DispatchQueue.main)
                                .sink(receiveValue: { [weak self] _ in
            self?.updateCounts()
        }))

        update()
    }
    
    func updateCounts() {
        for node in nodeArray {
            if let childNodes = node.children {
                for childNode in childNodes {
                    childNode.value.updateCount()
                    childNode.objectWillChange.send()
                }
            }
            node.value.updateCount()
            node.objectWillChange.send()
        }
    }

    func update() {
        nodeArray.removeAll()
        nodeArray.append(allItemsNode())
        nodeArray.append(starredItemsNode())

        if let folders = CDFolder.all() {
            for folder in folders {
                nodeArray.append(folderNode(folder: folder))
            }
        }
        if let feeds = CDFeed.inFolder(folder: 0) {
            for feed in feeds {
                nodeArray.append(feedNode(feed: feed))
            }
        }
        updateCounts()
    }

    private func allItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .all)
        let itemsNode = TreeNode(isLeaf: true,
                                 title: "All Articles",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(),
                                 sortId: 0,
                                 basePredicate: NSPredicate(value: true),
                                 nodeType: .all)
        return Node(itemsNode)
    }

    private func starredItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .starred)
        let itemsNode = TreeNode(isLeaf: true,
                                 title: "Starred Articles",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(feed: nil, isFolder: false, isStarred: true),
                                 sortId: 1,
                                 basePredicate: NSPredicate(format: "starred == true"),
                                 nodeType: .starred)
        return Node(itemsNode)
    }

    private func folderNode(folder: CDFolder) -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .folder(id: folder.id))

        var basePredicate: NSPredicate {
            if let feedIds = CDFeed.idsInFolder(folder: folder.id) {
                return NSPredicate(format: "feedId IN %@", feedIds)
            }
            return NSPredicate(value: false)
        }
        
        let folderNode = TreeNode(isLeaf: false,
                                       title: folder.name ?? "Untitled Folder",
                                       unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                       faviconImage: FavImage(feed: nil, isFolder: true),
                                       sortId: Int(folder.id) + 100,
                                       basePredicate: basePredicate,
                                       nodeType: .folder(id: folder.id))
        
        if let feeds = CDFeed.inFolder(folder: folder.id) {
            var children = [Node<TreeNode>]()
            for feed in feeds {
                children.append(feedNode(feed: feed))
            }
            return Node(folderNode, children: children)
        }
        return Node(folderNode)
    }

    private func feedNode(feed: CDFeed) -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .feed(id: feed.id))

        let itemsNode = TreeNode(isLeaf: true,
                                 title: feed.title ?? "Untitled Feed",
                                 unreadCount: unreadCount > 0 ? "\(unreadCount)" : nil,
                                 faviconImage: FavImage(feed: feed),
                                 sortId: Int(feed.id) + 1000,
                                 basePredicate: NSPredicate(format: "feedId == %d", feed.id),
                                 nodeType: .feed(id: feed.id))
        return Node(itemsNode)
    }

}
