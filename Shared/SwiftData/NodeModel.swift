//
//  NodeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/26/24.
//

import SwiftData

@Model
final public class NodeModel {

    var errorCount: Int64 = 0
    @Attribute(.unique) var nodeName: String
    var isExpanded = false
    var nodeType: NodeType
    var title: String
    var isTopLevel: Bool

    // Parental relationship
    public var parent: NodeModel?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \NodeModel.parent) var children: [NodeModel]?
    @Relationship(deleteRule: .noAction) var folder: Folder?
    @Relationship(deleteRule: .noAction) var feed: Feed?

    init(title: String, errorCount: Int64 = 0, nodeName: String, isExpanded: Bool = false, nodeType: NodeType, isTopLevel: Bool) {
        self.title = title
        self.errorCount = errorCount
        self.nodeName = nodeName
        self.isExpanded = isExpanded
        self.nodeType = nodeType
        self.isTopLevel = isTopLevel
    }

}

extension NodeModel: Identifiable { }
