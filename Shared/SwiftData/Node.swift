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
    var favIconURL: URL? = nil
    var pinned: UInt8 = 0
    @Attribute(.externalStorage) var favIcon: Data?

    // Parental relationship
    public var parent: Node?

    // Inverse
    @Relationship(deleteRule: .noAction, inverse: \Node.parent) var children: [Node]?
    @Relationship(deleteRule: .noAction) var folder: Folder?
    @Relationship(deleteRule: .noAction) var feed: Feed?

    init(id: String, type: NodeType, title: String, isExpanded: Bool = false, favIconURL: URL? = nil, children: [Node]? = nil, errorCount: Int64 = 0, pinned: UInt8 = 0, favIcon: Data? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.isExpanded = isExpanded
        self.favIconURL = favIconURL
        self.children = children
        self.errorCount = errorCount
        self.pinned = pinned
        self.favIcon = favIcon
    }

    convenience init(item: NodeDTO) {
        var childNodes = [Node]()
        if let childDTOs = item.children {
            for child in childDTOs {
                childNodes.append(Node(item: child))
            }
        }

        self.init(id: item.id, type: item.type, title: item.title, isExpanded: item.isExpanded, favIconURL: item.favIconURL, children: childNodes.isEmpty ? nil : childNodes , errorCount: item.errorCount, pinned: item.pinned, favIcon: item.favIcon)
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
