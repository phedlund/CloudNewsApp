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

    // Parental relationship
    public var parent: NodeModel?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \Folder.node) var folder: Folder?
    @Relationship(deleteRule: .noAction, inverse: \Feed.node) var feed: Feed?
    @Relationship(deleteRule: .noAction, inverse: \NodeModel.parent) var children: [NodeModel]?


    init(title: String, errorCount: Int64 = 0, nodeName: String, isExpanded: Bool = false, nodeType: NodeType) {
        self.title = title
        self.errorCount = errorCount
        self.nodeName = nodeName
        self.isExpanded = isExpanded
        self.nodeType = nodeType
    }

}

extension NodeModel: Identifiable { }
