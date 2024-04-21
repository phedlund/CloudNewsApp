//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import Foundation
import Observation
import SwiftData

@Observable
final class Node: Identifiable {
    private let feedModel: FeedModel

    var errorCount = 0
    var title = ""

    var id: String

    private(set) var isExpanded = false
    private(set) var nodeType = NodeType.empty
    private(set) var children: [Node]? = nil

    convenience init(feedModel: FeedModel) {
        self.init(.empty, id: Constants.allNodeGuid, isExpanded: false, feedModel: feedModel)
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false, feedModel: FeedModel) {
        self.init(nodeType, children: nil, id: id, isExpanded: isExpanded, feedModel: feedModel)
    }

    convenience init(folder: Folder, feedModel: FeedModel) {
        var children = [Node]()
        if let feeds = feedModel.modelContext.feedsInFolder(folder: folder.id) {
            for feed in feeds {
                children.append(Node(feed: feed, feedModel: feedModel))
            }
        }
        self.init(.folder(id: folder.id), children: children, id: "folder_\(folder.id)", isExpanded: folder.opened, feedModel: feedModel)
    }

    convenience init(feed: Feed, feedModel: FeedModel) {
        self.init(.feed(id: feed.id), children: nil, id: "feed_\(feed.id)", isExpanded: false, feedModel: feedModel)
    }

    init(_ nodeType: NodeType, children: [Node]? = nil, id: String, isExpanded: Bool, feedModel: FeedModel) {
        self.feedModel = feedModel
        self.nodeType = nodeType
        self.id = id
        self.isExpanded = isExpanded
        self.title = nodeTitle()
        self.children = children
    }

    func markRead() {
        var descriptor = FetchDescriptor<Item>()
        switch nodeType {
        case .empty:
            break
        case .all:
            descriptor.predicate = #Predicate<Item> { $0.unread == true }
        case .starred:
            descriptor.predicate = #Predicate<Item> { $0.starred == true }
        case .folder(let id):
            if let feedIds = self.feedModel.modelContext.feedIdsInFolder(folder: id) {
                descriptor.predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
            }
        case .feed(let id):
            descriptor.predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
        }
        do {
            let unreadItems = try feedModel.modelContext.fetch(descriptor)
            if !unreadItems.isEmpty {
                for item in unreadItems {
                    item.unread = false
                }
                try feedModel.modelContext.save()
                Task {
                    // TODO                       try await NewsManager.shared.markRead(items: unreadItems, unread: false)
                }
            }
        } catch {
            //
        }
    }

    private func nodeTitle() -> String {
        switch nodeType {
        case .empty:
            return ""
        case .all:
            return "All Articles"
        case .starred:
            return "Starred Articles"
        case .folder(let id):
            return feedModel.modelContext.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return feedModel.modelContext.feed(id: id)?.title ?? "Untitled Feed"
        }
    }

}

extension Node: Equatable {
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Node: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
