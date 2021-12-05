//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Combine
import CoreData

class FeedModel: ObservableObject {
    @Published var nodes = [Node]()

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

    private var cancellables = Set<AnyCancellable>()
    private var isInInit = false

    init(feedPublisher: AnyPublisher<[CDFeed], Never> = FeedStorage.shared.feeds.eraseToAnyPublisher(),
         folderPublisher: AnyPublisher<[CDFolder], Never> = FolderStorage.shared.folders.eraseToAnyPublisher()) {

        isInInit = true
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

        nodes.insert(starredItemsNode(), at: 0)
        nodes.insert(allItemsNode(), at: 0)
        update()
        isInInit = false
    }

    private func updateCounts(_ nodes: [Node]) {

        func update(_ node: Node) {
            node.title = nodeTitle(node.nodeType)
        }

        for node in nodes {
            for childNode in node.children {
                update(childNode)
            }

            update(node)
        }
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

    func update() {
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
            nodes.replaceSubrange(firstFolderIndex...lastFolderIndex, with: folderNodes)
        } else {
            nodes.append(contentsOf: folderNodes)
        }

        if let firstFeedIndex = nodes.firstIndex(where: { $0.id.hasPrefix("feed") }),
           let lastFeedIndex = nodes.lastIndex(where: { $0.id.hasPrefix("feed") }) {
            nodes.replaceSubrange(firstFeedIndex...lastFeedIndex, with: feedNodes)
        } else {
            nodes.append(contentsOf: feedNodes)
        }

        updateCounts(nodes)
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
        let node = Node(.all, id: AllNodeGuid)
        return node
    }

    private func starredItemsNode() -> Node {
        let node = Node(.starred, id: StarNodeGuid)
        return node
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
        return node
    }

}
