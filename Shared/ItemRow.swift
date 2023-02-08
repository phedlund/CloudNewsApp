//
//  ItemRow.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/23.
//

import SwiftUI

struct ItemRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var favIconRepository: FavIconRepository
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @ObservedObject var item: CDItem
    @ObservedObject var itemImageManager: ItemImageManager

    var size: CGSize
    var isHorizontalCompact: Bool

    @State private var thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)

    var body: some View {
        let isShowingThumbnail = (showThumbnails && itemImageManager.image != nil)
        let thumbnailOffset = isShowingThumbnail ? thumbnailSize.width + .paddingSix : .zero
        VStack(alignment: .leading, spacing: .zero) {
            HStack(alignment: .top, spacing: .zero) {
                ZStack(alignment: .topLeading) {
                    if isShowingThumbnail {
                        ItemImageView(image: itemImageManager.image,
                                      size: thumbnailSize)
                        .padding(.top, compactView ? 1 : .zero)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) { }
                        }
                    } else {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 1, height: thumbnailSize.height)
                    }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: .paddingSix) {
                            HStack {
                                VStack(alignment: .leading, spacing: .paddingSix) {
                                    HStack {
                                        TitleView(title: item.title ?? "Untitled")
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    FavIconDateAuthorView(title: item.dateFeedAuthor, feedId: item.feedId)
                                        .environmentObject(favIconRepository)
                                }
                            }
                            .padding(.leading, thumbnailOffset)
                            VStack(alignment: .leading) {
                                if compactView {
                                    EmptyView()
                                } else {
                                    HStack {
                                        BodyView(displayBody: item.displayBody)
                                        Spacer()
                                    }
                                    .padding(.leading, isHorizontalCompact ? .zero : thumbnailOffset)
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, isHorizontalCompact ? .zero : .paddingEight)
                        .padding(.leading, .paddingEight)
                    }
                    .padding(.trailing, 16)
                }
            }
            Spacer()
        }
        .listRowInsets(.none)
        .padding(.top, isHorizontalCompact ? .zero : .paddingEight)
        .padding(.top, isHorizontalCompact && compactView ? 22 : .zero)

#if os(iOS)
        .frame(width: size.width, height: size.height)
        .padding([.trailing], .paddingSix)
        .background(in: RoundedRectangle(cornerRadius: 1.0))
        .backgroundStyle(
            Color.pbh.whiteCellBackground
                .shadow(.drop(color: .init(.sRGBLinear, white: 0, opacity: 0.25), radius: 1, x: 0.75, y: 1))
        )
        .overlay(alignment: .topTrailing) {
            if item.starred {
                Image(systemName: "star.fill")
                    .padding([.top, .trailing],  .paddingSix)
            }
        }
        .overlay {
            if !item.unread, !item.starred {
                Color.primary
                    .colorInvert()
                    .opacity(0.6)
            }
        }
#else
        .overlay(alignment: .topTrailing) {
            if item.starred {
                Image(systemName: "star.fill")
                    .padding([.top, .trailing],  .paddingSix)
            }
        }
        .opacity(item.unread ? 1.0 : 0.4 )
#endif
        .onAppear {
            thumbnailSize = (compactView || isHorizontalCompact) ? CGSize(width: .compactThumbnailWidth, height: .compactCellHeight) : CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
            let _ = print(thumbnailSize)
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
