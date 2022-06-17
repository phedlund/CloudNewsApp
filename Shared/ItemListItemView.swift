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
    @State private var thumbnailWidth: CGFloat = 145.0
    @State private var thumbnailHeight: CGFloat = 160.0

    @ViewBuilder
    var body: some View {
#if !os(macOS)
        let isHorizontalCompact = horizontalSizeClass == .compact
#else
        let isHorizontalCompact = false
#endif
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                ItemImageView(model: model, size: CGSize(width: thumbnailWidth, height: thumbnailHeight))
                    .alignmentGuide(.top) { d in
                        (d[explicit: .top] ?? 0) - (settings.compactView ? 3 : 0)
                    }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        TitleView(model: model)
                        FavIconDateAuthorView(model: model)
                        if settings.compactView || isHorizontalCompact {
                            EmptyView()
                        } else {
                            BodyView(model: model)
                        }
                        Spacer()
                    }
                    .padding(.zero)
                    .padding(.top, 3)
                    Spacer()
                }
                .padding([.leading], settings.compactView || isHorizontalCompact ? 0 : 6)
                ItemStarredView(model: model)
            }
            if isHorizontalCompact && !settings.compactView  {
                HStack {
                    VStack {
                        BodyView(model: model)
                            .padding([.leading], 12)
                        Spacer()
                    }
                    Spacer(minLength: 26) // 16 (star view width) + 10 (HStack spacing above)
                }
            } else {
                EmptyView()
            }
        }
        .padding([.trailing], 10)
        .background(Color.pbh.whiteCellBackground
            .cornerRadius(4)
            .frame(height: cellHeight)
            .shadow(color: Color(white: 0.4, opacity: colorScheme == .light ? 0.35 : 0.65), radius: 2, x: 1, y: 2))
        .onReceive(settings.$compactView) { newCompactView in
            cellHeight = newCompactView ? 85.0 : 160.0
            thumbnailWidth = newCompactView ? 66.0 : isHorizontalCompact ? 66.0 : 145.0
            thumbnailHeight = newCompactView ? cellHeight : isHorizontalCompact ? cellHeight / 2 : cellHeight
        }
    }
    
}

