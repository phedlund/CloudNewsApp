//
//  FeedTreeNode.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation

protocol FeedTreeNode {
    var isLeaf: Bool { get }
    var title: String { get }
    var unreadCount: String { get }
    var sortId: Int { get }
    var basePredicate: NSPredicate { get }
    var nodeType: NodeType { get }
}

struct TreeNode: FeedTreeNode {
    var isLeaf: Bool
    var title: String {
        switch nodeType {
        case .all:
            return "All Articles"
        case .starred:
            return "Starred Articles"
        case .folder(let id):
            return CDFolder.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return CDFeed.feed(id: id)?.title ?? "Untitled Feed"
        }
    }
    var unreadCount: String {
        let count = CDItem.unreadCount(nodeType: nodeType)
        return count > 0 ? "\(count)" : ""
    }
    var sortId: Int
    var basePredicate: NSPredicate
    var nodeType: NodeType
}
