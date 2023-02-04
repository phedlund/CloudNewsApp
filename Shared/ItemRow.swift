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
    @ObservedObject var itemImageManager: ItemImageManager

    var itemDisplay: ItemDisplay
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
                            .foregroundColor(.pbh.whiteBackground)
                            .frame(width: 1, height: thumbnailSize.height)
                    }
                    HStack(alignment: .top) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: .paddingSix) {
                                HStack {
                                    VStack(alignment: .leading, spacing: .paddingSix) {
                                        HStack {
                                            TitleView(title: itemDisplay.title)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        FavIconDateAuthorView(title: itemDisplay.author, feedId: itemDisplay.feedId)
                                            .environmentObject(favIconRepository)
                                    }
                                }
                                .padding(.leading, thumbnailOffset)
                                VStack(alignment: .leading) {
                                    if compactView {
                                        EmptyView()
                                    } else {
                                        HStack {
                                            BodyView(displayBody: itemDisplay.body)
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
                        Spacer()
                        ItemStarredView(starred: itemDisplay.starred)
                    }
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
