//
//  ThumbnailImageView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/23.
//

import SwiftUI

struct ThumbnailImageView: View {
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true
    @AppStorage(SettingKeys.compactView) private var compactView = false
#if os(macOS)
    @State private var isHorizontalCompact = false
#else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isHorizontalCompact = false
#endif
    @State private var image: SystemImage?
    @State private var imageSize = CGSize.zero

    @Binding var thumbnailOffset: CGFloat

    private let itemImageManager: ItemImageManager

    init(item: Item, thumbnailOffset: Binding<CGFloat>) {
        self.itemImageManager = ItemImageManager(item: item)
        self._thumbnailOffset = thumbnailOffset
    }

    var body: some View {
        VStack {
            if itemImageManager.item.thumbNailImage != SystemImage() {
#if os(macOS)
                Image(nsImage: itemImageManager.item.thumbNailImage)
                    .imageStyle(size: imageSize)
#else
                Image(uiImage: itemImageManager.item.thumbNailImage)
                    .imageStyle(size: imageSize)
#endif
            } else {
                EmptyView()
            }
        }
        .onChange(of: compactView, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
        .onChange(of: showThumbnails, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
#if !os(macOS)
        .onChange(of: horizontalSizeClass) { _, newValue in
            isHorizontalCompact = newValue == .compact
        }
#endif
    }

    private func updateSizeAndOffset() {
        if !showThumbnails || itemImageManager.item.thumbNailImage == SystemImage() {
            thumbnailOffset = .zero
            imageSize = CGSize(width: 0, height: compactView ? .compactCellHeight : .defaultCellHeight)
        } else {
            if compactView {
                thumbnailOffset = .compactThumbnailWidth + .paddingSix
                imageSize = CGSize(width: .compactThumbnailWidth, height: .compactCellHeight)
            } else {
                thumbnailOffset = .defaultThumbnailWidth + .paddingSix
                imageSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
            }
        }
    }
}
