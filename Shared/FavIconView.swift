//
//  ItemFaviconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/27/21.
//

import SwiftUI

struct ItemFavIconView: View {
    @AppStorage(StorageKeys.showFavIcons) private var showFavIcons: Bool?

    var nodeType: NodeType

    @ViewBuilder
    var body: some View {
        if showFavIcons ?? true {
            FeedFavIconView(nodeType: nodeType)
        } else {
            EmptyView()
        }
    }
}

struct FeedFavIconView: View {
    var nodeType: NodeType = .all
    
    @ViewBuilder
    var body: some View {
        switch nodeType {
        case .empty, .all:
            Image("rss")
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
#if os(macOS)
            Image(nsImage: favIconImage(id))
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
#else
            Image(uiImage: favIconImage(id))
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
#endif
        }
    }

    private func favIconImage(_ feedId: Int32) -> SystemImage {
        var result = SystemImage(named: "rss") ?? SystemImage()
        if let feed = CDFeed.feed(id: feedId) {
            if let data = feed.favicon {
                result = SystemImage(data: data) ?? SystemImage()
            }
        }
        return result
    }

}
