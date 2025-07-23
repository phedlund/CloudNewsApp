//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/11/25.
//

import Foundation
import SwiftData

@Model
nonisolated final public class Node {
    #Index<Node>([\.id])

    @Attribute(.unique) public var id: String
    var errorCount: Int64 = 0
    var isExpanded = false
    var type: NodeType
    var title: String
    var pinned: UInt8 = 0

    // Parental relationship
    public var parent: Node?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \Node.parent) var children: [Node]?

    init(id: String, type: NodeType, title: String, isExpanded: Bool = false, children: [Node]? = nil, errorCount: Int64 = 0, pinned: UInt8 = 0) {
        self.id = id
        self.type = type
        self.title = title
        self.isExpanded = isExpanded
        self.children = children
        self.errorCount = errorCount
        self.pinned = pinned
    }

    convenience init(item: NodeDTO) {
        var childNodes = [Node]()
        if let childDTOs = item.children {
            for child in childDTOs {
                childNodes.append(Node(item: child))
            }
        }

        self.init(id: item.id,
                  type: item.type,
                  title: item.title,
                  isExpanded: item.isExpanded,
                  children: childNodes.isEmpty ? nil : childNodes ,
                  errorCount: item.errorCount,
                  pinned: item.pinned)
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
