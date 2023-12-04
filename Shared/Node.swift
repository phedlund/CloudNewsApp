//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import Foundation
import Observation

@Observable
final class Node: Identifiable {
    var unreadCount = 0
    var errorCount = 0
    var title = ""

    var id: String

    private(set) var isExpanded = false
    private(set) var nodeType = NodeType.empty
    private(set) var children: [Node]? = nil

    convenience init() {
        self.init(.empty, id: Constants.allNodeGuid, isExpanded: false)
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.init(nodeType, children: nil, id: id, isExpanded: isExpanded)
    }

    init(folder: Folder) {
        self.nodeType = .folder(id: folder.id)
        self.id = "folder_\(folder.id)"
        self.isExpanded = folder.opened
        self.title = folder.name ?? "Untitled Folder"
        if let feeds = Feed.inFolder(folder: folder.id) {
            var children = [Node]()
            for feed in feeds {
                children.append(Node(feed: feed))
            }
            self.children = children
        }
    }

    init(feed: Feed) {
        self.nodeType = .feed(id: feed.id)
        self.id = "feed_\(feed.id)"
        self.isExpanded = false
        self.title = feed.title ?? "Untitled Feed"
    }

    init(_ nodeType: NodeType, children: [Node]? = nil, id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.id = id
        self.isExpanded = isExpanded
        self.title = nodeTitle()
        self.children = children
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
            return Folder.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return Feed.feed(id: id)?.title ?? "Untitled Feed"
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
