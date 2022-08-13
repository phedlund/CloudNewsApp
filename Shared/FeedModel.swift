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
    @Published var currentItem: ArticleModel?

    private let allNode: Node
    private let starNode: Node
    private let preferences = Preferences()
    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
    private let feedPublisher = ItemStorage.shared.feeds.eraseToAnyPublisher()
    private let folderPublisher = ItemStorage.shared.folders.eraseToAnyPublisher()
    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: nil).eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()
    private var isInInit = false
    private var allItems = [CDItem]()

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

        syncPublisher
            .sink { [weak self] _ in
                self?.updateAllItems()
                self?.updateCurrentNodeItems()
            }
            .store(in: &cancellables)

        updateAllItems()
        update()
        isInInit = false
    }

    func update() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            var folderNodes = [Node]()
            var feedNodes = [Node]()
            
            if let folders = CDFolder.all() {
                for folder in folders {
                    folderNodes.append(self.folderNode(folder: folder))
                }
            }
            
            if let feeds = CDFeed.inFolder(folder: 0) {
                for feed in feeds {
                    feedNodes.append(self.feedNode(feed: feed))
                }
            }
            
            let firstFolderIndex = 2
            if let lastFolderIndex = self.nodes.lastIndex(where: { $0.id.hasPrefix("folder") }) {
                self.nodes.replaceSubrange(firstFolderIndex...lastFolderIndex, with: folderNodes)
            } else {
                self.nodes.append(contentsOf: folderNodes)
            }
            
            if let firstFeedIndex = self.nodes.firstIndex(where: { $0.id.hasPrefix("feed") }),
               let lastFeedIndex = self.nodes.lastIndex(where: { $0.id.hasPrefix("feed") }) {
                self.nodes.replaceSubrange(firstFeedIndex...lastFeedIndex, with: feedNodes)
            } else {
                self.nodes.append(contentsOf: feedNodes)
            }
            self.updateCurrentNode(self.preferences.selectedNode)
        }
    }

    func updateCurrentNode(_ current: String) {
        preferences.selectedNode = current
        currentNode = node(for: current) ?? Node(.empty, id: EmptyNodeGuid)
        updateCurrentNodeItems()
    }

    func updateCurrentItem(_ current: ArticleModel?) {
        currentItem = current
    }

    func delete(_ node: Node) {
        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            print("\(id)")
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
            print("\(id)")
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
            let node = Node(.folder(id: folder.id), children: children, id: "folder_\(folder.id)", isExpanded: folder.expanded)
            return node
        }
        let node = Node(.folder(id: folder.id), id: "folder_\(folder.id)", isExpanded: folder.expanded)
        return node
    }

    private func feedNode(feed: CDFeed) -> Node {
        let node = Node(.feed(id: feed.id), id: "feed_\(feed.id)")
        node.errorCount = Int(feed.updateErrorCount)
        return node
    }

    private func updateAllItems() {
        let itemsFetchRequest = CDItem.fetchRequest()
        let sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id,
                                                ascending: preferences.sortOldestFirst ? true : false)]
        let predicate = preferences.hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)
        itemsFetchRequest.sortDescriptors = sortDescriptors
        itemsFetchRequest.predicate = predicate
        do {
            allItems = try NewsData.mainThreadContext.fetch(itemsFetchRequest)
        } catch {
            print("Failed to fetch items")
        }
    }

    private func updateCurrentNodeItems() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.currentNode.nodeType {
            case .empty:
                break
            case .all:
                self.currentNode.items = self.allItems.map( { ArticleModel(item: $0) } )
            case .starred:
                self.currentNode.items = self.allItems
                    .filter( { $0.starred == true } )
                    .map( { ArticleModel(item: $0) } )
            case .folder(let id):
                if let feedIds = CDFeed.idsInFolder(folder: id) {
                    self.currentNode.items = self.allItems
                        .filter( { feedIds.contains($0.feedId) } )
                        .map( { ArticleModel(item: $0) } )
                } else {
                    self.allItems = []
                }
            case .feed(let id):
                self.currentNode.items = self.allItems
                    .filter( { $0.feedId == id } )
                    .map( { ArticleModel(item: $0) } )
            }
        }
    }

}
