//
//  FeedModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import Foundation
import Observation
import SwiftData

@Observable
class FeedModel {
    let modelContext: ModelContext
    let webImporter: WebImporter
//    let feedImporter: FeedImporter
//    let itemImporter: ItemImporter
    let itemPruner: ItemPruner
    let nodeBuilder: NodeBuilder
    let session = ServerStatus.shared.session

    var currentItems = [Item]()
    var currentItem: Item? = nil
//    var currentNodeID: NodeModel.
    var currentItemID: PersistentIdentifier? = nil
    var isSyncing = false

    private var isInInit = true

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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.modelContext.autosaveEnabled = true
        self.webImporter = WebImporter(modelContext: modelContext)
//        self.feedImporter = FeedImporter(modelContext: modelContext)
//        self.itemImporter = ItemImporter(modelContext: modelContext)
        self.itemPruner = ItemPruner(modelContext: modelContext)
        self.nodeBuilder = NodeBuilder(modelContext: modelContext)
//        nodes.append(Node(.all, id: Constants.allNodeGuid, feedModel: self))
//        nodes.append(Node(.starred, id: Constants.starNodeGuid, feedModel: self))
        self.nodeBuilder.update(isAppLaunch: true)
        isInInit = false
    }

    private func setup() {
//        do {
//            let nodeModelCount = try modelContext.fetchCount(FetchDescriptor<NodeModel>())
//            if nodeModelCount > 2 {
//                return
//            }
//
//        } catch { }
//
//        let allNodeModel = NodeModel(errorCount: 0, nodeName: Constants.allNodeGuid, isExpanded: false, nodeType: .all)
//        let starredNodeModel = NodeModel(errorCount: 0, nodeName: Constants.starNodeGuid, isExpanded: false, nodeType: .starred)
//        modelContext.insert(allNodeModel)
//        modelContext.insert(starredNodeModel)
//        if let folders = modelContext.allFolders() {
//            for folder in folders {
//                let folderNodeModel = NodeModel(errorCount: 0, nodeName: "cccc_\(String(format: "%03d", folder.id))", isExpanded: folder.opened, nodeType: .folder(id: folder.id))
//                folderNodeModel.folder = folder
//
//                var children = [NodeModel]()
//                if let feeds = modelContext.feedsInFolder(folder: folder.id) {
//                    for feed in feeds {
//                        let feedNodeModel = NodeModel(errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id))
//                        feedNodeModel.feed = feed
//                        children.append(feedNodeModel)
//                    }
//                }
//                folderNodeModel.children = children
//                modelContext.insert(folderNodeModel)
//            }
//        }
//        if let feeds = modelContext.feedsInFolder(folder: 0) {
//            for feed in feeds {
//                let feedNodeModel = NodeModel(errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id))
//                feedNodeModel.feed = feed
//                feedNodeModel.children = nil
//                modelContext.insert(feedNodeModel)
//            }
//        }
//        try? modelContext.save()
    }


    private func update() {
//        var folderNodes = [Node]()
//        var feedNodes = [Node]()
//
//        if let folders = modelContext.allFolders() {
//            for folder in folders {
//                folderNodes.append(Node(folder: folder, feedModel: self))
//            }
//        }
//
//        if let feeds = modelContext.feedsInFolder(folder: 0) {
//            for feed in feeds {
//                feedNodes.append(Node(feed: feed, feedModel: self))
//            }
//        }
//
////        let firstFolderIndex = 2
////        if let lastFolderIndex = nodes.lastIndex(where: { $0.id.hasPrefix("folder") }) {
////            self.nodes.replaceSubrange(firstFolderIndex...lastFolderIndex, with: folderNodes)
////        } else {
//            nodes.append(contentsOf: folderNodes)
////        }
//
////        if let firstFeedIndex = nodes.firstIndex(where: { $0.id.hasPrefix("feed") }),
////           let lastFeedIndex = nodes.lastIndex(where: { $0.id.hasPrefix("feed") }) {
////            self.nodes.replaceSubrange(firstFeedIndex...lastFeedIndex, with: feedNodes)
////        } else {
//            nodes.append(contentsOf: feedNodes)
////        }
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

    func delete(_ node: NodeModel) {
        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            Task {
                do {
                  try await deleteFolder(Int(id))
                    if let feedIds = modelContext.feedIdsInFolder(folder: id) {
                        for feedId in feedIds {
                            try await modelContext.deleteItems(with: feedId)
                            try await modelContext.deleteFolder(id: feedId)
                        }
                    }
                    try await modelContext.deleteFolder(id: id)
                } catch {
                    //
                }
            }
        case .feed(let id):
            Task {
                do {
                    try await deleteFeed(Int(id))
                    try await modelContext.deleteItems(with: id)
                    try await modelContext.deleteFeed(id: id)
                } catch {
                    //
                }
            }
        }
    }

//    func node(id: Node.ID) -> Node {
//        if let node = nodes.first(where: { $0.id == id } ) {
//            return node
//        } else {
//            let folderNodes = nodes.filter( { !($0.children?.isEmpty ?? false) })
//            for folderNode in folderNodes {
//                if let node = folderNode.children?.first(where: { $0.id == id } ) {
//                    return node
//                }
//            }
//            return Node(feedModel: self)
//        }
//    }

    func markItemsRead(items: [Item]) {
        guard !items.isEmpty else {
            return
        }
        for item in items {
            item.unread = false
        }
        Task.detached {
            try await self.markRead(items: items, unread: false)
        }
    }

    func toggleItemRead(item: Item) {
        do {
            item.unread.toggle()
            try modelContext.save()
            Task {
                try await self.markRead(items: [item], unread: !item.unread)
            }
        } catch {
            //
        }
    }

}
