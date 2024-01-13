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
    private var item: Item
    @State private var image = SystemImage()
    @State private var imageSize = CGSize.zero

    @Binding var thumbnailOffset: CGFloat

    init(item: Item, thumbnailOffset: Binding<CGFloat>) {
        self.item = item
        self._thumbnailOffset = thumbnailOffset
    }

    var body: some View {
        VStack {
            if image != SystemImage() {
#if os(macOS)
                Image(nsImage: image)
                    .imageStyle(size: imageSize)
#else
                Image(uiImage: image)
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
        .task {
            do {
                updateSizeAndOffset()
                image = try await item.itemImage
            } catch { }
        }
#if !os(macOS)
        .onChange(of: horizontalSizeClass) { _, newValue in
            isHorizontalCompact = newValue == .compact
        }
#endif
    }

    private func updateSizeAndOffset() {
        Task {
            do {
                let myImage = try await item.itemImage
                if !showThumbnails || myImage == SystemImage() {
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
    }
}
