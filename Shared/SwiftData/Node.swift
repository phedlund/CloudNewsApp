//
//  NodeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/26/24.
//

import SwiftData

@Model
final public class Node {

    var errorCount: Int64 = 0
    @Attribute(.unique) var nodeName: String
    var isExpanded = false
    var nodeType: NodeType
    var title: String
    var isTopLevel: Bool

    // Parental relationship
    public var parent: Node?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \Node.parent) var children: [Node]?
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

extension Node: Identifiable { }

extension Node {

    var wrappedChildren: [Node]? {
        get {
            if self.children?.count == 0 {
                return nil
            }
            return Array(self.children!)
        }
    }
}

