//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import CoreData
import Foundation
import SwiftUI

class AnyTreeNode: FeedTreeNode {

    typealias Child = AnyTreeNode

    var isLeaf: Bool
    var childCount: Int
    var children: [AnyTreeNode]?
    var items: [CDItem]
    var title: String
    var unreadCount: String?
    var faviconImage: FavImage?
    var sortId: Int

    init<T: FeedTreeNode>(_ x: T) {
        self.isLeaf = x.isLeaf
        self.childCount = x.childCount
        self.children = [AnyTreeNode]()
        if let children = children {
        for child in children {
            self.children?.append(AnyTreeNode(child))
        }
        }
        self.items = x.items
        self.title = x.title
        self.unreadCount = x.unreadCount
        self.faviconImage = x.faviconImage
        self.sortId = x.sortId
    }
}

class Node<T>: Identifiable {
    var id: Self { self }
    var value: T
    weak var parent: Node?
    var children: [Node]? = nil

    init(value: T) {
        self.value = value
    }

    func add(child: Node) {
        if children == nil {
            children = [Node]()
        }
        children?.append(child)
        child.parent = self
    }
}

class FeedTreeModel: NSObject, ObservableObject {
    @Published var feedTree: [Node<AnyTreeNode>]

    override init() {
        self.feedTree = [Node]()
        super.init()
        self.feedTree.removeAll()
        self.feedTree.append(Node(value: AnyTreeNode(AllFeedNode())))
        self.feedTree.append(Node(value: AnyTreeNode(StarredFeedNode())))
        if let folders = CDFolder.all() {
            for folder in folders {
                if let children = FolderFeedNode(folder: folder).children {
                    let folderNode = Node(value: AnyTreeNode(FolderFeedNode(folder: folder)))
                    for child in children  {
                        folderNode.add(child: Node(value: AnyTreeNode(child)))
                    }
                    self.feedTree.append(folderNode)
                } else {
                    self.feedTree.append(Node(value: AnyTreeNode(FolderFeedNode(folder: folder))))
                }

            }
        }
        if let feeds = CDFeed.inFolder(folder: 0) {
            for feed in feeds {
                self.feedTree.append(Node(value: AnyTreeNode(FeedNode(feed: feed))))
            }
        }
    }

}
