//
//  ItemFaviconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/27/21.
//

import Kingfisher
import SwiftUI

struct ItemFavIconView: View {
    @AppStorage(StorageKeys.showFavIcons) private var showFavIcons: Bool?

    var item: CDItem

    @ViewBuilder
    var body: some View {
        if showFavIcons ?? true {
            FeedFavIconView(nodeType: .feed(id: item.feedId))
                .opacity(item.unread ? 1.0 : 0.4)
        } else {
            EmptyView()
        }
    }
}

struct FeedFavIconView: View {
    static let validSchemas = ["http", "https", "file"]
    
    var nodeType: NodeType = .all
    
    @ViewBuilder
    var body: some View {
        switch nodeType {
        case .all:
            Image("favicon")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        case .starred:
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        case .folder( _):
            Image(systemName: "folder")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        case .feed(let id):
            if let feed = CDFeed.feed(id: id) {
                if let link = feed.faviconLink,
                   link != "favicon",
                   let url = URL(string: link),
                   let scheme = url.scheme,
                   FeedFavIconView.validSchemas.contains(scheme) {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 16, height: 16, alignment: .center)
                } else {
                    if let feedUrl = URL(string: feed.link ?? ""),
                       let host = feedUrl.host,
                       let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                        KFImage(url)
                            .placeholder {
                                Image("favicon")
                                    .resizable()
                                    .frame(width: 16, height: 16, alignment: .center)
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 16, height: 16, alignment: .center)
                    } else {
                        Image("favicon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16, alignment: .center)
                    }

                }
            }
        }
    }
}
