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
    var currentNode = Node(NodeType.empty, id: Constants.emptyNodeGuid)
    var currentItems = [Item]()
    var currentItem: Item? = nil
    var currentNodeID: Node.ID? = nil
    var currentItemID: PersistentIdentifier? = nil

//    @AppStorage(SettingKeys.hideRead) private var hideRead = false
//    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    private var hideRead = false
    private var sortOldestFirst = false

    private let allNode: Node
    private let starNode: Node
    private let preferences = Preferences()
//    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
//    private let feedPublisher = ItemStorage.shared.feeds.eraseToAnyPublisher()
//    private let folderPublisher = ItemStorage.shared.folders.eraseToAnyPublisher()
    private var fetchDescriptor = FetchDescriptor<Item>()
//
    private var cancellables = Set<AnyCancellable>()
    private var isInInit = true
    private var sortOrder: SortOrder = .reverse

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
        allNode = Node(.all, id: Constants.allNodeGuid)
        starNode = Node(.starred, id: Constants.starNodeGuid)
        nodes.append(allNode)
        nodes.append(starNode)

//        feedPublisher
//            .receive(on: DispatchQueue.main)
//            .sink { feeds in
//                self.feeds = feeds
//            }
//            .store(in: &cancellables)
//
//        folderPublisher
//            .receive(on: DispatchQueue.main)
//            .sink { folders in
//                self.folders = folders
//            }
//            .store(in: &cancellables)
//
//        changePublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] changes in
//                guard let self, !self.isInInit else { return }
//                if changes.contains(where: { $0.key == "folderId" }) {
//                    self.update()
//                }
//                self.allNode.unreadCount = CDItem.unreadCount(nodeType: .all)
//                self.starNode.unreadCount = CDItem.unreadCount(nodeType: .starred)
//            }
//            .store(in: &cancellables)
//
//        preferences.$selectedNode
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newNode in
//                guard let self, !self.isInInit else { return }
//                self.updateCurrentNode(newNode)
//            }
//            .store(in: &cancellables)
//
//        NewsManager.shared.syncSubject
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newValue in
//                guard let self else { return }
//                if newValue.previous == 0 {
//                    self.update()
//                    self.currentNodeID = Constants.allNodeGuid
//                    self.updateCurrentNode(Constants.allNodeGuid)
//                    self.publishItems()
//                } else {
//                    self.update()
//                    self.publishItems()
//                }
//            }
//            .store(in: &cancellables)
//
        update()
//        currentNodeID = preferences.selectedNode
//        updateCurrentNode(preferences.selectedNode)
//        fetchRequest.sortDescriptors = [NSSortDescriptor(SortDescriptor(\CDItem.id, order: .reverse))]
//        fetchRequest.fetchBatchSize = 20
//        publishItems()
        isInInit = false
    }

    private func update() {
        var folderNodes = [Node]()
        var feedNodes = [Node]()

        if let folders = Folder.all() {
            for folder in folders {
                folderNodes.append(folderNode(folder: folder))
            }
        }

        if let feeds = Feed.inFolder(folder: 0) {
            for feed in feeds {
                feedNodes.append(feedNode(feed: feed))
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

    private func updateCurrentNode(_ current: String) {
        currentNode = node(for: current) ?? Node(.empty, id: Constants.emptyNodeGuid)
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

    func updateVisibleItems() {
        publishItems()
    }

    func updateItemSorting() {
        sortOrder = sortOldestFirst ? .forward : .reverse
        self.publishItems()
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
            if let index = nodes.firstIndex(of: node) {
                nodes.remove(at: index)
            }
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

    private func node(for id: Node.ID) -> Node? {
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

    private func publishItems() {
        guard let currentNodeID else { return }
        print("Setting predicate")
        DispatchQueue.main.async {
            switch NodeType.fromString(typeString: currentNodeID) {
            case .empty:
                self.fetchDescriptor.predicate = #Predicate<Item>{ _ in
                    return false
                }
            case .all:
                self.fetchDescriptor.predicate = #Predicate<Item>{ _ in
                    return true
                }
            case .starred:
                self.fetchDescriptor.predicate = #Predicate<Item>{ $0.starred == true }
            case .folder(id:  let id):
                if let feedIds = Feed.idsInFolder(folder: id) {
                    self.fetchDescriptor.predicate = #Predicate<Item>{
                        return feedIds.contains($0.feedId)
                    }
                }
            case .feed(id: let id):
                self.fetchDescriptor.predicate = #Predicate<Item>{
                    return $0.feedId == id
                }
            }
            Task {
                do {
                    if let container = NewsData.shared.container {
                        let context = ModelContext(container)
                        self.currentItems = try context.fetch(self.fetchDescriptor).filter( { self.hideRead ? $0.unread == true : true } )
                    }
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        }
    }

    private func folderNode(folder: Folder) -> Node {
        if let feeds = Feed.inFolder(folder: folder.id) {
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

    private func feedNode(feed: Feed) -> Node {
        let node = Node(.feed(id: feed.id), id: "feed_\(feed.id)")
        node.errorCount = Int(feed.updateErrorCount)
        return node
    }

}
