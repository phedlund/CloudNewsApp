//
//  NodeBuilder.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/19/24.
//

import SwiftData
import Foundation
import OSLog

class NodeBuilder {

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: NodeBuilder.self))
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @MainActor
    func update() {
        let allNodeModel = Node(title: "All Articles", errorCount: 0, nodeName: Constants.allNodeGuid, isExpanded: false, nodeType: .all, isTopLevel: true)
        let starredNodeModel = Node(title: "Starred Articles", errorCount: 0, nodeName: Constants.starNodeGuid, isExpanded: false, nodeType: .starred, isTopLevel: true)
        modelContext.insert(allNodeModel)
        modelContext.insert(starredNodeModel)
        try? modelContext.save()
        if let folders = modelContext.allFolders() {
            for folder in folders {
                let folderNodeModel = Node(title: folder.name ?? "Untitled Folder", errorCount: 0, nodeName: "cccc_\(String(format: "%03d", folder.id))", isExpanded: folder.opened, nodeType: .folder(id: folder.id), isTopLevel: true)

                var children = [Node]()
                if let feeds = modelContext.feedsInFolder(folder: folder.id) {
                    for feed in feeds {
                        let feedNodeModel = Node(title: feed.title ?? "Untitled Feed", errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id), isTopLevel: false)
                        modelContext.insert(feedNodeModel)
                        feedNodeModel.feed = feed
                        children.append(feedNodeModel)
                        feed.node = feedNodeModel
                    }
                }
                modelContext.insert(folderNodeModel)
                folderNodeModel.folder = folder
                folderNodeModel.children = children
                folder.node = folderNodeModel
                try? modelContext.save()
            }
        }
        if let feeds = modelContext.feedsInFolder(folder: 0) {
            for feed in feeds {
                let feedNodeModel = Node(title: feed.title ?? "Untitled Feed", errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id), isTopLevel: true)
                feedNodeModel.feed = feed
                modelContext.insert(feedNodeModel)
//                feedNodeModel.children = nil
                feed.node = feedNodeModel
            }
            try? modelContext.save()
        }
    }

}
