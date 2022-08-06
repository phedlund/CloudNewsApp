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
    @State private var cellHeight: CGFloat = 160.0
    @State private var thumbnailSize = CGSize(width: 145.0, height: 157.0)

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
                ItemImageView(imageLink: model.imageLink,
                              size: thumbnailSize,
                              itemOpacity: itemOpacity)
                    .alignmentGuide(.top) { d in
                        (d[explicit: .top] ?? 0) - (settings.compactView ? 3 : 0)
                    }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        TitleView(title: model.title, textColor: textColor)
                        FavIconDateAuthorView(feedIcon: model.feedIcon,
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
            Rectangle()
                .fill(.gray.opacity(0.25))
                .frame(height: 1)
#endif
        }
#if os(iOS)
        .padding([.trailing], 10)
        .background(in: RoundedRectangle(cornerRadius: 4.0))
        .backgroundStyle(
            Color.pbh.whiteCellBackground.shadow(.drop(radius: 2, x: 0.5, y: 1))
        )
#endif
        .onAppear {
            if let imageLink = model.item?.imageLink, !imageLink.isEmpty {
                return
            } else {
                Task.detached(priority: .background) {
                    do {
                        try await ItemImageFetcher().itemURL(model.item!)
                    } catch { }
                }
            }
        }
        .onReceive(settings.$compactView) { newCompactView in
            cellHeight = newCompactView ? 82.0 : 157.0
            let thumbnailWidth = newCompactView ? 66.0 : isHorizontalCompact ? 66.0 : 145.0
            let thumbnailHeight = newCompactView ? cellHeight : isHorizontalCompact ? cellHeight / 2 : cellHeight
            thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        }
    }
    
}
