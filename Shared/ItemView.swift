//
//  ItemRow.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/23.
//

import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ItemView: View {
    @Environment(\.displayScale) private var displayScale: CGFloat
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.showFavIcons) private var showFavIcons = true
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true

    let item: Item
    let faviconData: Data?

    private var thumbnailImage: Image? {
        guard showThumbnails else { return nil }
        if let data = item.image ?? item.thumbnail {
#if os(macOS)
            if let nsImg = NSImage(data: data) { return Image(nsImage: nsImg) }
#else
            if let uiImg = UIImage(data: data, scale: displayScale) { return Image(uiImage: uiImg) }
#endif
        }
        return nil
    }

    private var faviconImage: Image? {
        guard showFavIcons else { return nil }
        if let data = faviconData {
#if os(macOS)
            if let nsImg = NSImage(data: data) { return Image(nsImage: nsImg) }
#else
            if let uiImg = UIImage(data: data) { return Image(uiImage: uiImg) }
#endif
        }
        return nil
    }

    private var effectiveFavicon: Image? {
        // Fallback to generic RSS icon if favicons are enabled but no data is available
        if let icon = faviconImage { return icon }
        return showFavIcons ? Image(.rss) : nil
    }

    private var cardMode: ItemCard.Mode {
        let hasThumb = (thumbnailImage != nil)
        if compactView {
            return hasThumb ? .compactWithImage : .compactNoImage
        } else {
            return hasThumb ? .largeWithImage : .largeNoImage
        }
    }

    var body: some View {
        ItemCard(
            title: item.displayTitle,
            subtitle: item.dateFeedAuthor,
            bodyText: item.displayBody,
            image: thumbnailImage,
            favicon: effectiveFavicon,
            showsFavicon: effectiveFavicon != nil,
            mode: cardMode,
            isStarred: item.starred,
            sizes: .init(
                largeHeight: .defaultCellHeight,
                compactHeight: .compactCellHeight,
                largeImageWidth: 145,
                compactImageWidth: 66,
                cornerRadius: 12,
                contentSpacing: 12,
                faviconSize: 22
            )
        )
        .listRowInsets(.none)
        .opacity((item.unread || item.starred) ? 1.0 : 0.4)
#if os(macOS)
        .containerRelativeFrame(.vertical, alignment: .center) { _, _ in
            return compactView ? .compactCellHeight : .defaultCellHeight
        }
#else
        .containerRelativeFrame([.horizontal, .vertical], alignment: .center) { length, axis in
            if axis == .vertical {
                return compactView ? .compactCellHeight : .defaultCellHeight
            } else {
                return min(length * 0.93, 700.0)
            }
        }
        .padding(.trailing, .paddingSix)
#endif
    }
}

//struct ItemRow_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemView()
//    }
//}

