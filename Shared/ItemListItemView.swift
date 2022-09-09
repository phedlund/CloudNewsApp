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
    @EnvironmentObject private var settings: Preferences
    @ObservedObject var model: ArticleModel
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
    @State private var icon = SystemImage()

    @ViewBuilder
    var body: some View {
#if !os(macOS)
        let isHorizontalCompact = horizontalSizeClass == .compact
#else
        let isHorizontalCompact = false
#endif
        let textColor = model.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        let itemOpacity = model.unread ? 1.0 : 0.4
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                ItemImageView(imageUrl: model.imageURL,
                              size: thumbnailSize,
                              itemOpacity: itemOpacity)
                    .alignmentGuide(.top) { d in
                        (d[explicit: .top] ?? 0) - (settings.compactView ? 3 : 0)
                    }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        TitleView(title: model.title, textColor: textColor)
                        FavIconDateAuthorView(feedIcon: model.feed?.faviconLinkResolved,
                                              dateAuthorFeed: model.dateAuthorFeed,
                                              textColor: textColor,
                                              itemOpacity: itemOpacity)
                        if settings.compactView || isHorizontalCompact {
                            EmptyView()
                        } else {
                            BodyView(displayBody: model.displayBody, textColor: textColor)
                        }
                        Spacer()
                    }
                    .padding(.zero)
                    .padding(.top, 3)
                    Spacer()
                }
                .padding([.leading], settings.compactView || isHorizontalCompact ? 0 : 6)
                ItemStarredView(starred: model.starred, textColor: textColor)
            }
            if isHorizontalCompact && !settings.compactView  {
                HStack {
                    VStack {
                        BodyView(displayBody: model.displayBody, textColor: textColor)
                            .padding([.leading], 12)
                        Spacer()
                    }
                    Spacer(minLength: 26) // 16 (star view width) + 10 (HStack spacing above)
                }
            } else {
                EmptyView()
            }
#if os(macOS)
            Spacer(minLength: 3)
            Divider()
#endif
        }
#if os(iOS)
        .padding([.trailing], 10)
        .background(in: RoundedRectangle(cornerRadius: 4.0))
        .backgroundStyle(
            Color.pbh.whiteCellBackground.shadow(.drop(radius: 2, x: 0.5, y: 1))
        )
#endif
        .onReceive(settings.$compactView) { newCompactView in
            cellHeight = newCompactView ? .compactCellHeight : .defaultCellHeight
            let thumbnailWidth = newCompactView ? CGFloat.compactThumbnailWidth : isHorizontalCompact ? .compactThumbnailWidth : .defaultThumbnailWidth
            let thumbnailHeight = newCompactView ? cellHeight : isHorizontalCompact ? .compactCellHeight : .defaultCellHeight
            thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        }
    }
    
}
