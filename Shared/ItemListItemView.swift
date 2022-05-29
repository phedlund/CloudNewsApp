//
//  ArticleListItemView.swift
//  iOCNews
//
//  Created by Peter Hedlund on 5/1/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftSoup
import SwiftUI
import Kingfisher

struct ItemListItemViev: View {
#if !os(macOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settings: Preferences
    @ObservedObject var item: CDItem
    @State private var cellHeight: CGFloat = 160.0
    @State private var thumbnailWidth: CGFloat = 145.0
    @State private var thumbnailHeight: CGFloat = 160.0

    @ViewBuilder
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                    ItemImageView(imageLink: item.imageLink, unread: item.unread, size: CGSize(width: thumbnailWidth, height: thumbnailHeight))
                    .alignmentGuide(.top) { d in
                        (d[explicit: .top] ?? 0) - (settings.compactView ? 3 : 0)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            TitleView(title: item.title ?? "Untitled", unread: item.unread)
                            FavIconDateAuthorView(dateAuthorFeed: item.dateAuthorFeed, unread: item.unread, feedId: item.feedId)
#if !os(macOS)
                            if settings.compactView || horizontalSizeClass == .compact {
                                EmptyView()
                            } else {
                                BodyView(bodyText: item.displayBody ?? "", unread: item.unread)
                            }
#else
                            if settings.compactView {
                                EmptyView()
                            } else {
                                BodyView(bodyText: item.displayBody ?? "", unread: item.unread)
                            }
#endif
                            Spacer()
                        }
                        .padding(.zero)
                        Spacer()
                    }
                    .padding([.top], 6)
#if !os(macOS)
                    .padding([.leading], settings.compactView || horizontalSizeClass == .compact ? 0 : 6)
#endif
                    ItemStarredView(starred: item.starred, unread: item.unread)
            }
#if !os(macOS)
            if horizontalSizeClass == .compact && !settings.compactView  {
                HStack {
                    VStack {
                        BodyView(bodyText: item.displayBody ?? "", unread: item.unread)
                            .padding([.leading], 12)
                        Spacer()
                    }
                    Spacer(minLength: 26) // 16 (star view width) + 10 (HStack spacing above)
                }
            } else {
                EmptyView()
            }
#else
            if !settings.compactView  {
                HStack {
                    VStack {
                        BodyView(bodyText: item.displayBody ?? "", unread: item.unread)
                            .padding([.leading], 12)
                        Spacer()
                    }
                    Spacer(minLength: 26) // 16 (star view width) + 10 (HStack spacing above)
                }
            } else {
                EmptyView()
            }
#endif
        }
        .padding([.trailing], 10)
        .background(Color.pbh.whiteCellBackground
            .cornerRadius(4)
            .frame(height: cellHeight)
            .shadow(color: Color(white: 0.4, opacity: colorScheme == .light ? 0.35 : 0.65), radius: 2, x: 1, y: 2))
        .onAppear() {
            ItemImageFetcher().itemURL(item)
        }
        .onReceive(settings.$compactView) { newCompactView in
            cellHeight = newCompactView ? 85.0 : 160.0
#if !os(macOS)
            thumbnailWidth = newCompactView ? 66.0 : horizontalSizeClass == .compact ? 66.0 : 145.0
            thumbnailHeight = newCompactView ? cellHeight : horizontalSizeClass == .compact ? cellHeight / 2 : cellHeight
#else
            thumbnailWidth = newCompactView ? 66.0 : 145.0
#endif
        }
    }
    
}

