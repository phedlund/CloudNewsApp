//
//  ItemRow.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/23.
//

import Kingfisher
import SwiftData
import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

struct ItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.showFavIcons) private var showFavIcons: Bool?
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true

    @State private var isHorizontalCompact = false
    @State private var thumbnailSize = CGSize.zero
    @State private var thumbnailOffset = CGFloat.zero

    private let item: Item
    private let cellSize: CGSize

    init(item: Item, size: CGSize) {
        self.item = item
        self.cellSize = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack(alignment: .top, spacing: .zero) {
                ZStack(alignment: .topLeading) {
                    thumbnailView
                        .padding(.top, compactView ? 1 : .zero)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: .paddingSix) {
                            HStack {
                                VStack(alignment: .leading, spacing: .paddingSix) {
                                    titleView
                                    favIconDateAuthorView
                                    if isHorizontalCompact {
                                        Spacer()
                                    } else {
                                        EmptyView()
                                    }
                                }
                            }
                            .padding(.leading, thumbnailOffset)
                            bodyView
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
        .padding(.top, isHorizontalCompact && compactView ? .paddingEight : .zero)
        .onChange(of: compactView, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
        .onChange(of: showThumbnails, initial: true) { _, newValue in
            updateSizeAndOffset()
        }
#if os(iOS)
        .frame(width: cellSize.width, height: cellSize.height)
        .padding([.trailing], .paddingSix)
        .background(in: RoundedRectangle(cornerRadius: 1.0))
        .backgroundStyle(
            Color.phWhiteCellBackground
                .shadow(.drop(color: .init(.sRGBLinear, white: 0, opacity: 0.25), radius: 1, x: 0.75, y: 1))
        )
        .overlay(alignment: .topTrailing) {
            if item.starred {
                Image(systemName: "star.fill")
                    .padding([.top, .trailing],  .paddingSix)
            }
        }
        .if(!item.unread && !item.starred) {
            $0.opacity(0.4)
        }
        .task {
            Task { @MainActor in
                updateSizeAndOffset()
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
#if !os(macOS)
        .onChange(of: horizontalSizeClass) { _, newValue in
            isHorizontalCompact = newValue == .compact
        }
#endif
    }
}

private extension ItemView {

    @MainActor
    var titleView: some View {
        HStack {
            Text(item.title ?? "Untitled")
                .multilineTextAlignment(.leading)
                .font(Font.headline.weight(.semibold))
#if os(iOS)
                .foregroundColor(.phWhiteText)
#endif
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true) //force wrapping
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    var favIconDateAuthorView: some View {
        Label {
            Text(item.dateFeedAuthor)
                .font(.subheadline)
                .italic()
#if os(iOS)
                .foregroundColor(.phWhiteText)
#endif
                .lineLimit(1)
        } icon: {
            KFImage(item.feed?.favIconURL)
                .placeholder {
                    Image(.rss)
                        .font(.system(size: 18, weight: .light))
                }
                .resizable()
                .frame(width: 22, height: 22)
        }
        .labelStyle(includeFavIcon: showFavIcons ?? true)
    }

    @MainActor
    var bodyView: some View {
        VStack(alignment: .leading) {
            if compactView {
                EmptyView()
            } else {
                HStack(alignment: .top) {
                    Text(item.displayBody)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .font(.body)
#if os(iOS)
                        .foregroundColor(.phWhiteText)
#endif
                    Spacer()
                }
                .padding(.leading, thumbnailOffset)
            }
        }
        .if(isHorizontalCompact) {
            $0.frame(height: thumbnailSize.height - 4)
        }
    }

    @MainActor
    var thumbnailView: some View {
        VStack {
            KFImage(item.thumbnailURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipped()
        }
    }

    @MainActor
    private func updateSizeAndOffset() {
        if !showThumbnails {
            thumbnailOffset = .zero
            thumbnailSize = CGSize(width: 0, height: compactView ? .compactCellHeight : .defaultCellHeight)
        } else {
            if item.thumbnailURL != nil {
                if compactView {
                    thumbnailOffset = .compactThumbnailWidth + .paddingSix
                    thumbnailSize = CGSize(width: .compactThumbnailWidth, height: .compactCellHeight)
                } else {
                    thumbnailOffset = .defaultThumbnailWidth + .paddingSix
                    thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
                }
            } else {
                thumbnailOffset = .zero
                thumbnailSize = CGSize(width: 0, height: compactView ? .compactCellHeight : .defaultCellHeight)
            }
        }
    }

}

//struct ItemRow_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemRow()
//    }
//}

extension View {
    @ViewBuilder
    func bodyFrame(active: Bool, height: CGFloat) -> some View {
        if active, height >= 0 {
            self.frame(height: height)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func labelStyle(includeFavIcon: Bool) -> some View {
        if includeFavIcon {
            self.labelStyle(.titleAndIcon)
        } else {
            self.labelStyle(.titleOnly)
        }
    }
}
