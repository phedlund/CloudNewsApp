//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData
import SwiftUI
import SwiftSoup

class FeedModel: ObservableObject {
    @Published var nodes = [Node]()

    private var isHidingRead = false
    private var isSortingOldestFirst = false

    private var folders = [CDFolder]() {
        willSet {
//            nodes = update()
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

    func nodeItems(_ nodeType: NodeType) -> [ArticleModel] {
        var filteredItems = [CDItem]()
        var result = [ArticleModel]()

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
        for filteredItem in filteredItems {
            result.append(ArticleModel(item: filteredItem))
        }
        return result.sorted(by: { isSortingOldestFirst ? $1.item.id > $0.item.id : $0.item.id > $1.item.id })
    }

    private func updateCounts(_ nodes: [Node]) {

        func update(_ node: Node) {
            node.unreadCount = nodeUnreadCount(node.nodeType)
            node.title = nodeTitle(node.nodeType)
        }

        for node in nodes {
            for childNode in node.children {
                update(childNode)
            }

            update(node)
        }
    }
    
    private func nodeUnreadCount(_ nodeType: NodeType) -> String {
        let count = CDItem.unreadCount(nodeType: nodeType)
        return count > 0 ? "\(count)" : ""
    }

    private func nodeTitle(_ nodeType: NodeType) -> String {
        switch nodeType {
        case .all:
            return "All Articles"
        case .starred:
            return "Starred Articles"
        case .folder(let id):
            return CDFolder.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return CDFeed.feed(id: id)?.title ?? "Untitled Feed"
        }
    }

    func update() -> [Node] {
        var result = [Node]()

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

    func delete(_ node: Node) {
        switch node.nodeType {
        case .all, .starred:
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

    private func allItemsNode() -> Node {
        let unreadCount = CDItem.unreadCount(nodeType: .all)
        let node = Node(.all, id: AllNodeGuid)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

    private func starredItemsNode() -> Node {
        let unreadCount = CDItem.unreadCount(nodeType: .starred)
        let node = Node(.starred, id: StarNodeGuid)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

    private func folderNode(folder: CDFolder) -> Node {
        let unreadCount = CDItem.unreadCount(nodeType: .folder(id: folder.id))

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
            node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
            return node
        }
        let node = Node(.folder(id: folder.id), id: "folder_\(folder.id)", isExpanded: folder.expanded)
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

    private func feedNode(feed: CDFeed) -> Node {
        let unreadCount = CDItem.unreadCount(nodeType: .feed(id: feed.id))
        let node = Node(.feed(id: feed.id), id: "feed_\(feed.id)")
        node.unreadCount = unreadCount > 0 ? "\(unreadCount)" : ""
        return node
    }

}
