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
    static let validSchemas = ["http", "https", "file"]

    var feed: CDFeed?
    var isFolder = false
    var isStarred = false

    @ViewBuilder
    var body: some View {
        if let link = feed?.faviconLink, link != "favicon", let url = URL(string: link), let scheme = url.scheme, FavImage.validSchemas.contains(scheme) {
            AsyncImage(url: url, content: { phase in
                switch phase {
                case .empty:
                    Color.purple.opacity(0.1)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    FeedFavImage(feed: feed)
                @unknown default:
                    Image("favicon")
                        .resizable()
                        .scaledToFit()
                }
            })
            .frame(width: 16, height: 16, alignment: .center)
        } else if isFolder {
            Image(systemName: "folder")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        } else if isStarred {
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        } else {
            FeedFavImage(feed: feed)
        }
    }
}

struct FeedFavImage: View {
    var feed: CDFeed?

    @ViewBuilder
    var body: some View {
        if let feed = feed,
            let feedUrl = URL(string: feed.link ?? ""),
            let host = feedUrl.host,
            let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
            AsyncImage(url: url, content: { phase in
                switch phase {
                case .empty:
                    Color.purple.opacity(0.1)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    Image("favicon")
                        .resizable()
                        .scaledToFit()
                @unknown default:
                    Image("favicon")
                        .resizable()
                        .scaledToFit()
                }
            })
                .frame(width: 16, height: 16, alignment: .center)
        } else {
            Image("favicon")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        }
    }
}
