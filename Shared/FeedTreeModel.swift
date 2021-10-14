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

    private(set) var children: [Node]?

    init() {
        value = TreeNode(isLeaf: true,
                         sortId: -1,
                         basePredicate: NSPredicate(value: true),
                         nodeType: .all) as! Value
        title = "All Articles"
    }

    init(_ value: Value) {
        self.value = value
    }

    init(_ value: Value, children: [Node]) {
        self.value = value
        self.children = children
    }

}

extension Node: Equatable where Value: Equatable {
    static func == (lhs: Node, rhs: Node) -> Bool {
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

class FeedTreeModel: ObservableObject {
    @Published var nodes = [Node<TreeNode>]()

    private var isHidingRead = false
    private var isSortingOldestFirst = false

    private var folders = [CDFolder]() {
        willSet {
            nodes = update()
        }
    }
    private var feeds = [CDFeed]()  {
        willSet {
            nodes = update()
        }
    }
    private var items = [CDItem]()

    private var preferences = Preferences()
    private var cancellables = Set<AnyCancellable>()

    init(feedPublisher: AnyPublisher<[CDFeed], Never> = FeedStorage.shared.feeds.eraseToAnyPublisher(),
         folderPublisher: AnyPublisher<[CDFolder], Never> = FolderStorage.shared.folders.eraseToAnyPublisher(),
         itemPublisher: AnyPublisher<[CDItem], Never> = ItemStorage.shared.items.eraseToAnyPublisher()) {
        itemPublisher.sink { items in
            print("Updating in Tree Model")
            self.items = items
            self.updateCounts(self.nodes)
        }
        .store(in: &cancellables)
        feedPublisher.sink { feeds in
            print("Updating Feeds")
            self.feeds = feeds
        }
        .store(in: &cancellables)
        folderPublisher.sink { folders in
            print("Updating Folders")
            self.folders = folders
        }
        .store(in: &cancellables)

        preferences.$hideRead.sink { [weak self] newHideRead in
            guard let self = self else { return }
            self.isHidingRead = newHideRead
        }
        .store(in: &cancellables)

        preferences.$sortOldestFirst.sink { [weak self] newSortOldestFirst in
            guard let self = self else { return }
            self.isSortingOldestFirst = newSortOldestFirst
        }
        .store(in: &cancellables)
    }

    func nodeItems(_ nodeType: NodeType) -> [CDItem] {
        var filteredItems = [CDItem]()

        switch nodeType {
        case .all:
            filteredItems = items.filter({ isHidingRead ? $0.unread : true })
        case .starred:
            filteredItems = items.filter { item in
                let check1 = item.starred == true
                let check2 = isHidingRead ? item.unread : true
                return check1 && check2
            }
        case .folder(let id):
            if let feedIds = CDFeed.idsInFolder(folder: id) {
                filteredItems = items.filter { item in
                    let check1 = feedIds.contains(item.feedId)
                    let check2 = isHidingRead ? item.unread : true
                    return check1 && check2
                }
            }
        case .feed(let id):
            filteredItems = items.filter { item in
                let check1 = item.feedId == id
                let check2 = isHidingRead ? item.unread : true
                return check1 && check2
            }
        }
        return filteredItems.sorted(by: { isSortingOldestFirst ? $1.id > $0.id : $0.id > $1.id })
    }

    private func updateCounts(_ nodes: [Node<TreeNode>]) {

        func update(_ node: Node<TreeNode>) {
            node.unreadCount = node.value.unreadCount
            node.title = node.value.title
        }

        for node in nodes {
            if let childNodes = node.children {
                for childNode in childNodes {
                    update(childNode)
                }
            }
            update(node)
        }
    }

    func update() -> [Node<TreeNode>] {
        var result = [Node<TreeNode>]()

        result.append(allItemsNode())
        result.append(starredItemsNode())

        if let folders = CDFolder.all() {
            for folder in folders {
                result.append(folderNode(folder: folder))
            }
        }
        if let feeds = CDFeed.inFolder(folder: 0) {
            for feed in feeds {
                result.append(feedNode(feed: feed))
            }
        }
        updateCounts(result)
        return result
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
