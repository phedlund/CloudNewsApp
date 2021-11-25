//
//  ItemFaviconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/27/21.
//

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
            Image(uiImage: favIconImage(id))
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
        }
    }

    private func favIconImage(_ feedId: Int32) -> UIImage {
        var result = UIImage(named: "favicon") ?? UIImage()
        if let feed = CDFeed.feed(id: feedId) {
            if let data = feed.favicon {
                result = UIImage(data: data) ?? UIImage()
            }
        }
        return result
    }

}
