//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData
import SwiftUI

@MainActor
class FeedModel: ObservableObject {
    @Published var nodes = [Node]()
    @Published var currentNode = Node(.empty, id: EmptyNodeGuid)
    @Published var currentItem: CDItem?

    private let allNode: Node
    private let starNode: Node
    private let preferences = Preferences()
    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
    private let feedPublisher = ItemStorage.shared.feeds.eraseToAnyPublisher()
    private let folderPublisher = ItemStorage.shared.folders.eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()
    private var isInInit = false

    private var folders = [CDFolder]() {
        didSet {
            if !isInInit {
                update()
            }
        }
    }
    private var feeds = [CDFeed]()  {
        didSet {
            if !isInInit {
                update()
            }
        }
    }
    
    init() {
        isInInit = true
        allNode = Node(.all, id: AllNodeGuid)
        starNode = Node(.starred, id: StarNodeGuid)
        nodes.append(allNode)
        nodes.append(starNode)

        feedPublisher.sink { feeds in
            self.feeds = feeds
        }
        .store(in: &cancellables)
        folderPublisher.sink { folders in
            self.folders = folders
        }
        .store(in: &cancellables)

        changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changes in
                guard let self, !self.isInInit else { return }
                if changes.contains(where: { $0.key == "folderId" }) {
                    self.update()
                }
                self.allNode.unreadCount = CDItem.unreadCount(nodeType: .all)
                self.starNode.unreadCount = CDItem.unreadCount(nodeType: .starred)
            }
            .store(in: &cancellables)

        preferences.$selectedNode.sink { [weak self] newNode in
            guard let self, !self.isInInit else { return }
            self.updateCurrentNode(newNode)
        }
        .store(in: &cancellables)

        update()
        isInInit = false
    }

    func update() {
        Task(priority: .high) {
            var folderNodes = [Node]()
            var feedNodes = [Node]()

            if let folders = CDFolder.all() {
                for folder in folders {
                    folderNodes.append(folderNode(folder: folder))
                }
            }

            if let feeds = CDFeed.inFolder(folder: 0) {
                for feed in feeds {
                    feedNodes.append(feedNode(feed: feed))
                }
            }

            let firstFolderIndex = 2
            if let lastFolderIndex = nodes.lastIndex(where: { $0.id.hasPrefix("folder") }) {
                DispatchQueue.main.async { [weak self] in
                    self?.nodes.replaceSubrange(firstFolderIndex...lastFolderIndex, with: folderNodes)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.nodes.append(contentsOf: folderNodes)
                }
            }

            if let firstFeedIndex = nodes.firstIndex(where: { $0.id.hasPrefix("feed") }),
               let lastFeedIndex = nodes.lastIndex(where: { $0.id.hasPrefix("feed") }) {
                DispatchQueue.main.async { [weak self] in
                    self?.nodes.replaceSubrange(firstFeedIndex...lastFeedIndex, with: feedNodes)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.nodes.append(contentsOf: feedNodes)
                }
            }
        }
    }

    func updateCurrentNode(_ current: String) {
        currentNode = node(for: current) ?? Node(.empty, id: EmptyNodeGuid)
    }

    func updateCurrentItem(_ current: CDItem?) {
        currentItem = current
    }

    func delete(_ node: Node) {
        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            if let index = nodes.firstIndex(of: node) {
                nodes.remove(at: index)
            }
            Task {
                do {
                    try await NewsManager.shared.deleteFolder(Int(id))
                    if let feedIds = CDFeed.idsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await CDItem.deleteItems(with: feedId)
                            try await CDFeed.delete(id: feedId)
                        }
                    }
                    try await CDFolder.delete(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            if let index = nodes.firstIndex(of: node) {
                nodes.remove(at: index)
            }
            Task {
                do {
                    try await NewsManager.shared.deleteFeed(Int(id))
                    try await CDItem.deleteItems(with: id)
                    try await CDFeed.delete(id: id)
                } catch {
                    //
                }
            }
        }
    }

    func node(for id: Node.ID) -> Node? {
        if let node = nodes.first(where: { $0.id == id} ) {
            return node
        }
        for node in nodes {
            if let child = node.children?.first(where: { $0.id == id} ) {
                return child
            }
        }
        return nil
    }

    private func folderNode(folder: CDFolder) -> Node {

        var basePredicate: NSPredicate {
            if let feedIds = CDFeed.idsInFolder(folder: folder.id) {
                return NSPredicate(format: "feedId IN %@", feedIds)
            }
            return NSPredicate(value: false)
        }
        
        if let feeds = CDFeed.inFolder(folder: folder.id) {
            var children = [Node]()
            for feed in feeds {
                children.append(feedNode(feed: feed))
            }
            let node = Node(.folder(id: folder.id), children: children, id: "folder_\(folder.id)", isExpanded: folder.opened)
            return node
        }
        let node = Node(.folder(id: folder.id), id: "folder_\(folder.id)", isExpanded: folder.opened)
        return node
    }

    private func feedNode(feed: CDFeed) -> Node {
        let node = Node(.feed(id: feed.id), id: "feed_\(feed.id)")
        node.errorCount = Int(feed.updateErrorCount)
        return node
    }

}
