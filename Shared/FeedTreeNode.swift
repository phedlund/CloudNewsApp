//
//  FeedTreeNode.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import SwiftUI

protocol FeedTreeNode {
    var isLeaf: Bool { get }
    var items: [CDItem] { get }
    var title: String { get }
    var unreadCount: String? { get }
    var faviconImage: FavImage? { get }
    var sortId: Int { get }
    var basePredicate: NSPredicate { get }
    var nodeType: NodeType { get }

    mutating func updateCount()
}

struct TreeNode: FeedTreeNode {
    var isLeaf: Bool
    var items: [CDItem]
    var title = ""
    var unreadCount: String?
    var faviconImage: FavImage?
    var sortId: Int
    var basePredicate: NSPredicate
    var nodeType: NodeType
    mutating func updateCount() {
        let count = CDItem.unreadCount(nodeType: nodeType)
        if count > 0 {
            unreadCount = "\(count)"
        }
    }
}

struct FavImage: View {
    var feed: CDFeed?
    var isFolder = false
    var isStarred = false

    @ViewBuilder
    var body: some View {
        if let faviconLink = feed?.faviconLink, let url = URL(string: faviconLink) {
            AsyncImage(url: url, content: { phase in
                switch phase {
                case .empty:
                    Color.purple.opacity(0.1)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    Image(systemName: "exclamationmark.icloud")
                        .resizable()
                        .scaledToFit()
                @unknown default:
                    Image(systemName: "exclamationmark.icloud")
                }
            })
                .frame(width: 16, height: 16, alignment: .center)
        } else if isFolder {
            Image(systemName: "folder")
        } else if isStarred {
            Image(systemName: "star.fill")
        } else {
            Image("favicon")
        }
    }
}
