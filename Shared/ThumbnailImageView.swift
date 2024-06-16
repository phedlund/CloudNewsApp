//
//  ThumbnailImageView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/23.
//

import NukeUI
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
    @State private var imageSize = CGSize.zero
    @State private var url: URL?

    @Binding var thumbnailOffset: CGFloat

    init(item: Item, thumbnailOffset: Binding<CGFloat>) {
        self.item = item
        self._thumbnailOffset = thumbnailOffset
    }

    var body: some View {
        VStack {
            LazyImage(url: url)  { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image("rss")
                        .font(.system(size: 18, weight: .light))
                } else {
                    ProgressView()
                }
            }
            .frame(width: imageSize.width, height: imageSize.height)
            .clipped()
        }
        .onChange(of: compactView, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
        .onChange(of: showThumbnails, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
        .task {
            updateSizeAndOffset()
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
                if !showThumbnails {
                    thumbnailOffset = .zero
                    imageSize = CGSize(width: 0, height: compactView ? .compactCellHeight : .defaultCellHeight)
                } else {
                    url = try await item.imageUrl
                    if url != nil {
                        if compactView {
                            thumbnailOffset = .compactThumbnailWidth + .paddingSix
                            imageSize = CGSize(width: .compactThumbnailWidth, height: .compactCellHeight)
                        } else {
                            thumbnailOffset = .defaultThumbnailWidth + .paddingSix
                            imageSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
                        }
                    } else {
                        thumbnailOffset = .zero
                        imageSize = CGSize(width: 0, height: compactView ? .compactCellHeight : .defaultCellHeight)
                    }
                }
            }
        }
    }

}
