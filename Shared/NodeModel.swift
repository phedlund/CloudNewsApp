//
//  NodeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/26/24.
//

import SwiftData

@Model
final class NodeModel: Identifiable {

    var errorCount: Int64 = 0
    @Attribute(.unique) var id: String
    var isExpanded = false
    var nodeType = NodeType.empty
    var children: [NodeModel]?
    @Relationship(deleteRule: .cascade) var folder: Folder?
    @Relationship(deleteRule: .cascade) var feed: Feed?
    @Relationship(deleteRule: .nullify, inverse: \NodeModel.children) var parentItem: NodeModel?

    var title: String {
        switch nodeType {
        case .empty:
            return ""
        case .all:
            return "All Articles"
        case .starred:
            return "Starred Articles"
        case .folder(_ ):
            return folder?.name ?? "Untitled Folder"
        case .feed(_ ):
            return feed?.title ?? "Untitled Feed"
        }
    }

    init(errorCount: Int64 = 0, id: String, isExpanded: Bool = false, nodeType: NodeType = NodeType.empty) {
        self.errorCount = errorCount
        self.id = id
        self.isExpanded = isExpanded
        self.nodeType = nodeType
    }

}
