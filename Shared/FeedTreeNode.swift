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
    associatedtype Child: FeedTreeNode

    var isLeaf: Bool { get }
    var childCount: Int { get }
    var children: [Child]? { get }
    var items: [CDItem] { get }
    var title: String { get }
    var unreadCount: String? { get }
    var faviconImage: FavImage? { get }
    var sortId: Int { get }
}

struct AllFeedNode: FeedTreeNode {
    typealias Child = Self

    var sortId: Int {
        return 0
    }
    
    var isLeaf: Bool {
        return true
    }
    
    var childCount: Int {
        return 0
    }
    
    var children: [Child]? {
        return nil
    }

    var items: [CDItem] {
        CDItem.all() ?? []
    }

    var title: String {
        return "All Articles"
    }
    
    var unreadCount: String? {
        let count = CDItem.unreadCount()
        if count > 0 {
            return "\(count)"
        }
        return nil
    }
    
    var faviconImage: FavImage? {
        return FavImage()
    }
    
}

struct StarredFeedNode: FeedTreeNode {
    typealias Child = Self

    var sortId: Int {
        return 1
    }

    var isLeaf: Bool {
        get {
            return true
        }
    }
    
    var childCount: Int {
        get {
            return 0
        }
    }
    
    var children: [Child]? {
        get {
            return nil
        }
    }
    
    var items: [CDItem] {
        CDItem.starredItems() ?? []
    }

    var title: String {
        get {
            return "Starred Articles"
        }
    }
    
    var unreadCount: String? {
        get {
            let count = CDItem.starredItems()?.count ?? 0
            if count > 0 {
                return "\(count)"
            }
            return nil
        }
    }
    
    var faviconImage: FavImage? {
        get {
            return FavImage(feed: nil, isFolder: false, isStarred: true)
        }
    }
    
}

struct FolderFeedNode: FeedTreeNode {
    typealias Child = FeedNode

    var sortId: Int {
        return Int(self.folder.id) + 100
    }

    let folder: CDFolder
    
    init(folder: CDFolder){
        self.folder = folder
    }
    
    var isLeaf: Bool {
        get {
            return false
        }
    }
    
    var childCount: Int {
        get {
            var count = 0
            if let feedIds = CDFeed.idsInFolder(folder: self.folder.id) {
                count = feedIds.count
            }
            return count
        }
    }
    
    var children: [Child]? {
        get {
            var result = [FeedNode]()
            if let feeds = CDFeed.inFolder(folder: self.folder.id) {
                for feed in feeds {
                    result.append(FeedNode(feed: feed))
                }
            }
            return result
        }
    }

    var items: [CDItem] {
        return []
    }

    var title: String {
        get {
            return self.folder.name ?? "Untitled Folder"
        }
    }
    
    var unreadCount: String? {
        get {
            let count = CDItem.unreadCount(folder: self.folder.id)
            if count > 0 {
                return "\(count)"
            }
            return nil
        }
    }
    
    var faviconImage: FavImage? {
        get {
            return FavImage(feed: nil, isFolder: true)
        }
    }
    
}

struct FeedNode: FeedTreeNode {
    typealias Child = Self

    var sortId: Int {
        return Int(self.feed.id) + 1000
    }

    let feed: CDFeed
    
    init(feed: CDFeed){
        self.feed = feed
    }
    
    var isLeaf: Bool {
        get {
            return true
        }
    }
    
    var childCount: Int {
        get {
            return 0
        }
    }
    
    var children: [Child]? {
        get {
            return nil
        }
    }
    
    var items: [CDItem] {
        if let items = CDItem.items(feed: feed.id) {
            return items
        }
        return []
    }

    var title: String {
        get {
            return self.feed.title ?? "Untitled Feed"
        }
    }
    
    var unreadCount: String? {
        get {
            let count = CDItem.unreadCount(feed: self.feed.id)
            if count > 0 {
                return "\(count)"
            }
            return nil
        }
    }
    
    var faviconImage: FavImage? {
        get {
            FavImage(feed: feed)
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
