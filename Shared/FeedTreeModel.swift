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
    @Published var preferences = Preferences()
    @Published var nodes = [Node<TreeNode>]()

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

    private var cancellables = Set<AnyCancellable>()

    init(feedPublisher: AnyPublisher<[CDFeed], Never> = FeedStorage.shared.feeds.eraseToAnyPublisher(),
         folderPublisher: AnyPublisher<[CDFolder], Never> = FolderStorage.shared.folders.eraseToAnyPublisher()) {
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

        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidMergeChangesObjectIDs, object: NewsData.mainThreadContext)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateCounts(self.nodes)
            }
            .store(in: &cancellables)
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateCounts(self.nodes)
            }
            .store(in: &cancellables)

        preferences.$hideRead.sink { [weak self] newHideRead in
            guard let self = self else { return }
            self.updatePredicate(self.nodes, hideRead: newHideRead)
        }
        .store(in: &cancellables)

        preferences.$sortOldestFirst.sink { [weak self] newSortOldestFirst in
            guard let self = self else { return }
            self.updateSortOldestFirst(self.nodes, sortOldestFirst: newSortOldestFirst)
        }
        .store(in: &cancellables)
    }

    private func updatePredicate(_ nodes: [Node<TreeNode>], hideRead: Bool) {

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

        for node in nodes {
            if let childNodes = node.children {
                for childNode in childNodes {
                    update(childNode)
                }
            }
            update(node)
        }
    }

    private func updateSortOldestFirst(_ nodes: [Node<TreeNode>], sortOldestFirst: Bool) {
        let sortDescriptors = [SortDescriptor(\CDItem.pubDate, order: sortOldestFirst ? .forward : .reverse)]

        for node in nodes {
            if let childNodes = node.children {
                for childNode in childNodes {
                    childNode.sortDescriptors = sortDescriptors
                }
            }
            node.sortDescriptors = sortDescriptors
        }
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
        updatePredicate(result, hideRead: preferences.hideRead)
        updateSortOldestFirst(result, sortOldestFirst: preferences.sortOldestFirst)
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
