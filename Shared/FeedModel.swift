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
    @Published var selectedNode: String?
    private let preferences = Preferences()

    @Published var currentNode = Node(.all, id: AllNodeGuid)

    private let allNode: Node
    private let starNode: Node

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

    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
    private let feedPublisher = ItemStorage.shared.feeds.eraseToAnyPublisher()
    private let folderPublisher = ItemStorage.shared.folders.eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()
    private var isInInit = false

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
                guard let self = self else { return }
                if changes.contains(where: { $0.key == "folderId" }) {
                    self.update()
                }
                self.allNode.unreadCount = CDItem.unreadCount(nodeType: .all)
                self.starNode.unreadCount = CDItem.unreadCount(nodeType: .starred)
            }
            .store(in: &cancellables)

        $selectedNode.sink { [weak self] in
            guard let self = self else { return }
            if let id = $0 {
                print("Selected node with id \(id)")
                self.preferences.selectedNode = id
                
                if let node = self.nodes.first(where: { $0.id == id }) {
                    self.currentNode = node
                } else {
                    let folderNodes = self.nodes.filter {
                        switch $0.nodeType {
                        case .folder:
                            return true
                        default:
                            return false
                        }
                    }
                    for folderNode in folderNodes {
                        if let node = folderNode.children?.first(where: { $0.id == id }) {
                            self.currentNode = node
                            break
                        } else {
                            self.currentNode = self.allNode
                        }
                    }
                }
            }
        }
        .store(in: &cancellables)

        if !preferences.selectedNode.isEmpty {
            selectedNode = preferences.selectedNode
        } else {
            selectedNode = allNode.id
        }
        update()
        isInInit = false
    }

    func selectionBindingForId(id: String) -> Binding<Bool> {
        Binding<Bool> { () -> Bool in
            self.selectedNode == id
        } set: { (newValue) in
            if newValue {
                self.selectedNode = id
            }
        }
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
            if let node = self.nodes.first(where: { $0.id == self.selectedNode }) {
                self.currentNode = node
            } else {
                self.currentNode = self.allNode
            }
        }
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

}
