//
//  ItemRow.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/23.
//

import SwiftUI

struct ItemRow: View {
    
#if !os(macOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @ObservedObject var item: CDItem

    var size: CGSize

    @State private var thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
    @State private var imageUrl: URL?
    
    var body: some View {
#if os(macOS)
        let isHorizontalCompact = false
#else
        let isHorizontalCompact = horizontalSizeClass == .compact
#endif
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        let itemOpacity = item.unread ? 1.0 : 0.4
        let isShowingThumbnail = (showThumbnails && item.imageUrl != nil)
        let thumbnailOffset = isShowingThumbnail ? thumbnailSize.width : 0
        let feed = CDFeed.feed(id: item.feedId)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if isShowingThumbnail {
                        ItemImageView(imageUrl: imageUrl,
                                      size: thumbnailSize,
                                      itemOpacity: itemOpacity)
                        .padding(.top, compactView ? 1 : 0)
                    } else {
                        Rectangle()
                            .foregroundColor(.pbh.whiteBackground)
                            .frame(width: 1, height: thumbnailSize.height)
                    }
                    HStack(alignment: .top) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            TitleView(title: item.title ?? "Untitled", textColor: textColor, itemOpacity: itemOpacity)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        FavIconDateAuthorView(feedIcon: feed?.faviconLinkResolved,
                                                              dateAuthorFeed: item.dateFeedAuthor,
                                                              itemOpacity: itemOpacity)
                                    }
                                }
                                .padding(.leading, thumbnailOffset)
                                VStack(alignment: .leading) {
                                    if compactView {
                                        EmptyView()
                                    } else {
                                        HStack {
                                            BodyView(displayBody: item.displayBody, textColor: textColor, itemOpacity: itemOpacity)
                                            Spacer()
                                        }
                                        .padding(.leading, isHorizontalCompact ? 0 : thumbnailOffset)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.top, isHorizontalCompact ? 0 : 8)
                            .padding(.leading, 8)

                        }
                        Spacer()
                        ItemStarredView(starred: item.starred, textColor: textColor)
                    }
                }
            }
            Spacer()
        }
        .listRowInsets(.none)
        .padding(.top, isHorizontalCompact ? 0 : 8)
        .padding(.top, isHorizontalCompact && compactView ? 22 : 0)

#if os(iOS)
        .frame(width: size.width, height: size.height)
        .padding([.trailing], 10)
        .background(in: RoundedRectangle(cornerRadius: 4.0))
        .backgroundStyle(
            Color.pbh.whiteCellBackground
                .shadow(.drop(radius: 2, x: 0.5, y: 1))
        )
#endif
        .onAppear {
            thumbnailSize = (compactView || isHorizontalCompact) ? CGSize(width: .compactThumbnailWidth, height: .compactCellHeight) : CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
            imageUrl = item.imageUrl as? URL
        }
        .onChange(of: $item.imageUrl.wrappedValue) { newValue in
            imageUrl = newValue as? URL
        }
        .onChange(of: $compactView.wrappedValue) { newValue in
            let cellHeight = newValue ? CGFloat.compactCellHeight : CGFloat.defaultCellHeight
            let thumbnailWidth = newValue ? CGFloat.compactThumbnailWidth : isHorizontalCompact ? .compactThumbnailWidth : .defaultThumbnailWidth
            let thumbnailHeight = newValue ? cellHeight : isHorizontalCompact ? .compactCellHeight : .defaultCellHeight
            thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        }
    }
}

//struct ItemRow_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemRow()
//    }
//}
