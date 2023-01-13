//
//  ArticleListItemView.swift
//  iOCNews
//
//  Created by Peter Hedlund on 5/1/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftSoup
import SwiftUI

struct ItemListItemViev: View {
#if !os(macOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @ObservedObject var item: CDItem
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)

    @ViewBuilder
    var body: some View {
#if os(macOS)
        let isHorizontalCompact = false
#else
        let isHorizontalCompact = horizontalSizeClass == .compact
#endif
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        let itemOpacity = item.unread ? 1.0 : 0.4
        let isShowingThumbnail = (showThumbnails && item.imageUrl != nil)
        let hSpacing: CGFloat = isShowingThumbnail ? 10 : 0
        let feed = CDFeed.feed(id: item.feedId)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: hSpacing) {
                if isShowingThumbnail {
                    ItemImageView(imageUrl: item.imageUrl as URL?,
                                  size: thumbnailSize,
                                  itemOpacity: itemOpacity)
                    .alignmentGuide(.top) { d in
                        (d[explicit: .top] ?? 0) - (compactView ? 3 : 0)
                    }
                } else {
                    EmptyView()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        TitleView(title: item.title ?? "Untitled", textColor: textColor, itemOpacity: itemOpacity)
                        FavIconDateAuthorView(feedIcon: feed?.faviconLinkResolved,
                                              dateAuthorFeed: item.dateFeedAuthor,
                                              itemOpacity: itemOpacity)
                        if compactView || isHorizontalCompact {
                            EmptyView()
                        } else {
                            BodyView(displayBody: item.displayBody, textColor: textColor, itemOpacity: itemOpacity)
                        }
                        Spacer()
                    }
                    .padding(.zero)
                    .padding(.top, 3)
                    Spacer()
                }
                .padding([.leading], compactView || isHorizontalCompact ? 0 : 6)
                ItemStarredView(starred: item.starred, textColor: textColor)
            }
            if isHorizontalCompact && !compactView  {
                HStack {
                    VStack {
                        BodyView(displayBody: item.displayBody, textColor: textColor, itemOpacity: itemOpacity)
                            .padding([.leading], 12)
                        Spacer()
                    }
                    Spacer(minLength: 26) // 16 (star view width) + 10 (HStack spacing above)
                }
            } else {
                EmptyView()
            }
        }
#if os(iOS)
        .padding([.trailing], 10)
        .background(in: RoundedRectangle(cornerRadius: 4.0))
        .backgroundStyle(
            Color.pbh.whiteCellBackground.shadow(.drop(radius: 2, x: 0.5, y: 1))
        )
#endif
        .onChange(of: $compactView.wrappedValue) { newValue in
            cellHeight = newValue ? .compactCellHeight : .defaultCellHeight
            let thumbnailWidth = newValue ? CGFloat.compactThumbnailWidth : isHorizontalCompact ? .compactThumbnailWidth : .defaultThumbnailWidth
            let thumbnailHeight = newValue ? cellHeight : isHorizontalCompact ? .compactCellHeight : .defaultCellHeight
            thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        }
    }
    
}
