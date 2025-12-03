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

struct ItemView: View, Equatable {
    static func == (lhs: ItemView, rhs: ItemView) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.item.unread == rhs.item.unread &&
        lhs.item.starred == rhs.item.starred &&
        lhs.faviconData == rhs.faviconData
    }

    @Environment(\.displayScale) private var displayScale: CGFloat
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.showFavIcons) private var showFavIcons = true
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true

    let item: Item
    let faviconData: Data?

    // Cache the computed image to avoid recreating it
    @State private var cachedFaviconImage: Image?

    private var thumbnailUrl: URL? {
        guard showThumbnails else { return nil }
        return item.thumbnailURL
    }

    private var effectiveFavicon: Image? {
        // Use cached image if available
        if let cached = cachedFaviconImage {
            return cached
        }
        // Fallback to generic RSS icon if favicons are enabled but no data
        return showFavIcons ? Image(.rss) : nil
    }

    private var cardMode: ItemCard.Mode {
        let hasThumb = (thumbnailUrl != nil)
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
            imageUrl: item.thumbnailURL,
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
        .task(id: faviconData) {
            // Convert Data to Image once and cache it
            if let data = faviconData, showFavIcons {
#if os(macOS)
                if let nsImg = NSImage(data: data) {
                    cachedFaviconImage = Image(nsImage: nsImg)
                }
#else
                if let uiImg = UIImage(data: data) {
                    cachedFaviconImage = Image(uiImage: uiImg)
                }
#endif
            } else {
                cachedFaviconImage = nil
            }
        }
    }
}

//struct ItemRow_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemView()
//    }
//}

