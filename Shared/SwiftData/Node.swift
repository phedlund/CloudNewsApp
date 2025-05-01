//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/11/25.
//

import Foundation
import SwiftData

@Model
final public class Node {
    #Index<Node>([\.id])

    @Attribute(.unique) public var id: String
    var errorCount: Int64 = 0
    var isExpanded = false
    var type: NodeType
    var title: String
    var favIconURL: URL? = nil
    var pinned: UInt8 = 0

    // Parental relationship
    public var parent: Node?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \Node.parent) var children: [Node]?
    @Relationship(deleteRule: .noAction) var folder: Folder?
    @Relationship(deleteRule: .noAction) var feed: Feed?

    init(id: String, type: NodeType, title: String, isExpanded: Bool = false, favIconURL: URL? = nil, children: [Node]? = nil, errorCount: Int64 = 0, pinned: UInt8 = 0) {
        self.id = id
        self.type = type
        self.title = title
        self.isExpanded = isExpanded
        self.favIconURL = favIconURL
        self.children = children
        self.errorCount = errorCount
        self.pinned = pinned
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
