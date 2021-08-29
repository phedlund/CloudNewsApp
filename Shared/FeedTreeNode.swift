//
//  FeedTreeNode.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import SwiftUI
import URLImage

protocol FeedTreeNode {
    var isLeaf: Bool { get }
    var title: String { get }
    var unreadCount: String { get }
    var faviconImage: FavImage? { get }
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
    var faviconImage: FavImage?
    var sortId: Int
    var basePredicate: NSPredicate
    var nodeType: NodeType
}

struct FavImage: View {
    static let validSchemas = ["http", "https", "file"]

    var feed: CDFeed?
    var isFolder = false
    var isStarred = false

    @ViewBuilder
    var body: some View {
        if let link = feed?.faviconLink, link != "favicon", let url = URL(string: link), let scheme = url.scheme, FavImage.validSchemas.contains(scheme) {
            URLImage(url) {
                // This view is displayed before download starts
                EmptyView()
            } inProgress: { progress in
                // Display progress
                EmptyView()
            } failure: { error, retry in
                // Display error and retry button
                EmptyView()
            } content: { image in
                // Downloaded image
                image
                    .resizable()
                    .scaledToFill()
            }
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
            URLImage(url) {
                // This view is displayed before download starts
                EmptyView()
            } inProgress: { progress in
                // Display progress
                EmptyView()
            } failure: { error, retry in
                // Display error and retry button
                Image("favicon")
                    .resizable()
                    .scaledToFit()
            } content: { image in
                // Downloaded image
                image
                    .resizable()
                    .scaledToFill()
            }
                .frame(width: 16, height: 16, alignment: .center)
        } else {
            Image("favicon")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        }
    }
}
