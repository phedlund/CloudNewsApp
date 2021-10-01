//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData
import SwiftUI

final class Node<Value>: Identifiable, ObservableObject {
    @Published var value: Value
    @Published var unreadCount: String?
    @Published var title: String?
    @Published var predicate = NSPredicate(value: true)
    @Published var sortDescriptors = [SortDescriptor(\CDItem.pubDate, order: .reverse)]

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
    @Published var preferences = Preferences()
    @Published var nodeArray = [Node<TreeNode>]()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidMergeChangesObjectIDs, object: NewsData.mainThreadContext)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCounts()
            }
            .store(in: &cancellables)
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCounts()
            }
            .store(in: &cancellables)

        preferences.$hideRead.sink { [weak self] newHideRead in
            self?.updatePredicate(newHideRead)
        }
        .store(in: &cancellables)

        preferences.$sortOldestFirst.sink { [weak self] newSortOldestFirst in
            self?.updateSortOldestFirst(newSortOldestFirst)
        }
        .store(in: &cancellables)

        update()
    }

    private func updatePredicate(_ hideRead: Bool) {

        func update(_ node: Node<TreeNode>) {
            switch node.value.nodeType {
            case .all:
                node.predicate = NSCompoundPredicate(type: .and, subpredicates: [NSPredicate(value: true), unredPredicate])
            case .starred:
                node.predicate =  NSCompoundPredicate(type: .and, subpredicates: [NSPredicate(format: "starred == true"), unredPredicate])
            case .folder(let id):
                if let feedIds = CDFeed.idsInFolder(folder: id) {
                    node.predicate =  NSCompoundPredicate(type: .and, subpredicates: [NSPredicate(format: "feedId IN %@", feedIds), unredPredicate])
                } else {
                    node.predicate =  NSPredicate(value: false)
                }
            case .feed(let id):
                node.predicate =  NSCompoundPredicate(type: .and, subpredicates: [NSPredicate(format: "feedId == %d", id), unredPredicate])
            }
        }

        let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)

        for node in nodeArray {
            if let childNodes = node.children {
                for childNode in childNodes {
                    update(childNode)
                }
            }
            update(node)
        }
    }

    func updateSortOldestFirst(_ sortOldestFirst: Bool) {
        let sortDescriptors = [SortDescriptor(\CDItem.pubDate, order: sortOldestFirst ? .forward : .reverse)]

        for node in nodeArray {
            if let childNodes = node.children {
                for childNode in childNodes {
                    childNode.sortDescriptors = sortDescriptors
                }
            }
            node.sortDescriptors = sortDescriptors
        }
    }

    func updateCounts() {

        func update(_ node: Node<TreeNode>) {
            node.unreadCount = node.value.unreadCount
            node.title = node.value.title
        }

        for node in nodeArray {
            if let childNodes = node.children {
                for childNode in childNodes {
                    update(childNode)
                }
            }
            update(node)
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
        updatePredicate(preferences.hideRead)
        updateSortOldestFirst(preferences.sortOldestFirst)
    }

    private func allItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .all)
        let itemsNode = TreeNode(isLeaf: true,
                                 sortId: 0,
                                 basePredicate: NSPredicate(value: true),
                                 nodeType: .all)
        let node = Node(itemsNode)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

    private func starredItemsNode() -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .starred)
        let itemsNode = TreeNode(isLeaf: true,
                                 sortId: 1,
                                 basePredicate: NSPredicate(format: "starred == true"),
                                 nodeType: .starred)
        let node = Node(itemsNode)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node

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
                                       sortId: Int(folder.id) + 100,
                                       basePredicate: basePredicate,
                                       nodeType: .folder(id: folder.id))
        
        if let feeds = CDFeed.inFolder(folder: folder.id) {
            var children = [Node<TreeNode>]()
            for feed in feeds {
                children.append(feedNode(feed: feed))
            }
            let node = Node(folderNode, children: children)
            node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
            return node
        }
        let node = Node(folderNode)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

    private func feedNode(feed: CDFeed) -> Node<TreeNode> {
        let unreadCount = CDItem.unreadCount(nodeType: .feed(id: feed.id))

        let itemsNode = TreeNode(isLeaf: true,
                                 sortId: Int(feed.id) + 1000,
                                 basePredicate: NSPredicate(format: "feedId == %d", feed.id),
                                 nodeType: .feed(id: feed.id))
        let node = Node(itemsNode)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

}
