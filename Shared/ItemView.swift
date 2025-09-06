//
//  ItemRow.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/23.
//

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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.showFavIcons) private var showFavIcons = true
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails = true

    @State private var isHorizontalCompact = false
    @State private var thumbnailSize = CGSize.zero
    @State private var thumbnailOffset = CGFloat.zero
    @State private var thumbnailImage: SystemImage?
    @State private var faviconImage: SystemImage?

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
                    if showThumbnails {
                        thumbnailView
                            .padding(.top, compactView ? 1 : .zero)
                    } else {
                        EmptyView()
                    }
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
        .if(!item.unread && !item.starred) {
            $0.opacity(0.4)
        }
        .background(Color.phWhiteCellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay() {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.black.opacity(0.15), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if item.starred {
                Image(systemName: "star.fill")
                    .padding([.top, .trailing],  .paddingSix)
            }
        }
        .onAppear {
            updateSizeAndOffset()
            if let imageData = item.image, let uiImage = SystemImage(data: imageData) {
                self.thumbnailImage = uiImage
            }

            let feedId = item.feedId
            var fetchDescriptor = FetchDescriptor<FavIcon>(predicate: #Predicate<FavIcon> { $0.id == feedId })
            fetchDescriptor.fetchLimit = 1
            if let favIcon = try? modelContext.fetch(fetchDescriptor).first {
                if let data = favIcon.icon {
                    if let uiImage = SystemImage(data: data) {
                        self.faviconImage = uiImage
                    }
                }
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
            if showFavIcons {
                if let faviconImage {
#if os(macOS)
                    Image(nsImage: faviconImage)
                        .resizable()
                        .frame(width: 22, height: 22)
#else
                    Image(uiImage: faviconImage)
                        .resizable()
                        .frame(width: 22, height: 22)
#endif
                } else {
                    Image(.rss)
                        .font(.system(size: 18, weight: .light))
                }
            } else {
                EmptyView()
            }
        }
        .labelStyle(.titleAndIcon)
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
            if let thumbnailImage {
                #if os(macOS)
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .clipped()
#else
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .clipped()
                #endif
            }
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

