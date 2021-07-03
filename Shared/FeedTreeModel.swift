//
//  FeedTreeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/20/21.
//

import CoreData
import Foundation
import SwiftUI

struct AnyTreeNode: FeedTreeNode, Identifiable {
    typealias ID = UUID
    typealias Child = Self

    var id: ID
    var isLeaf: Bool
    var childCount: Int
    var children: [AnyTreeNode]
    var items: [CDItem]
    var title: String
    var unreadCount: String?
    var faviconImage: Image?
    var sortId: Int

    init<T: FeedTreeNode>(_ x: T) {
        self.id = UUID()
        self.isLeaf = x.isLeaf
        self.childCount = x.childCount
        self.children = [AnyTreeNode]()
        for child in x.children {
            self.children.append(AnyTreeNode(child))
        }
        self.items = x.items
        self.title = x.title
        self.unreadCount = x.unreadCount
        self.faviconImage = x.faviconImage
        self.sortId = x.sortId
    }
}

class FeedTreeModel: NSObject, ObservableObject {
    @Published var feedTree: [AnyTreeNode]

    override init() {
        self.feedTree = [AnyTreeNode]()
        super.init()
        self.feedTree.removeAll()
        self.feedTree.append(AnyTreeNode(AllFeedNode()))
        self.feedTree.append(AnyTreeNode(StarredFeedNode()))
        if let folders = CDFolder.all() {
            for folder in folders {
                self.feedTree.append(AnyTreeNode(FolderFeedNode(folder: folder)))
            }
        }
        if let feeds = CDFeed.inFolder(folder: 0) {
            for feed in feeds {
                self.feedTree.append(AnyTreeNode(FeedNode(feed: feed)))
            }
        }
    }

}
