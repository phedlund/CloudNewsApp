//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import Kingfisher
import SwiftUI

struct ItemListToolbarContent: ToolbarContent {
    @ObservedObject var node: Node

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            MarkReadButton(node: node)
        }
    }
}

struct ContextMenuContent: View {
    @ObservedObject var item: CDItem

    var body: some View {
        Button {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: !item.unread)
            }
        } label: {
            Label {
                Text(item.unread ? "Read" : "Unread")
            } icon: {
                Image(systemName: item.unread ? "eye" : "eye.slash")
            }
        }
        Button {
            Task {
                try? await NewsManager.shared.markStarred(item: item, starred: !item.starred)
            }
        } label: {
            Label {
                Text(item.starred ? "Unstar" : "Star")
            } icon: {
                Image(systemName: item.starred ? "star" : "star.fill")
            }
        }
    }
}

struct TitleView: View {
    let font = Font.headline.weight(.semibold)
    var title: String
    var textColor: Color
    var itemOpacity: Double

    var body: some View {
        Text(title)
            .multilineTextAlignment(.leading)
            .font(font)
        #if os(macOS)
            .opacity(itemOpacity)
        #else
            .foregroundColor(textColor)
        #endif
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true) //force wrapping
    }
}

struct FavIconLabelStyle: LabelStyle {
    @AppStorage(SettingKeys.showFavIcons) private var showFavIcons: Bool?

    func makeBody(configuration: Configuration) -> some View {
        if showFavIcons ?? true {
            HStack {
                configuration.icon
                configuration.title
            }
        } else {
            configuration.title
        }
    }
}

struct FavIconDateAuthorView: View {
    @ObservedObject var item: CDItem
    @EnvironmentObject private var favIconRepository: FavIconRepository

    var body: some View {
        Label {
            Text(item.dateFeedAuthor)
                .font(.subheadline)
                .italic()
                .lineLimit(1)
        } icon: {
            FavIconView(favIcon: favIconRepository.icons["feed_\(item.feedId)"] ?? favIconRepository.defaultIcon)
                .environmentObject(favIconRepository)
        }
        .labelStyle(FavIconLabelStyle())
        .opacity(item.unread ? 1.0 : 0.4)
    }
}

struct BodyView: View {
    var displayBody: String
    var textColor: Color
    var itemOpacity: Double
    
    @ViewBuilder
    var body: some View {
        Text(displayBody)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
#if os(macOS)
            .opacity(itemOpacity)
#else
            .foregroundColor(textColor)
#endif
    }
}

struct ItemImageView: View {
    var image: KFCrossPlatformImage?
    var size: CGSize
    var itemOpacity: Double

    init(image: KFCrossPlatformImage?, size: CGSize, itemOpacity: Double) {
        self.image = image
        self.size = size
        self.itemOpacity = itemOpacity
    }

    var body: some View {
        VStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(itemOpacity)
            } else {
                EmptyView()
                    .frame(width: .zero)
            }
        }
    }
}

struct ItemStarredView: View {
    var starred: Bool
    var textColor: Color

    @ViewBuilder
    var body: some View {
        VStack(alignment: .trailing) {
            if starred {
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(textColor)
                    .frame(width: 16, height: 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
    }
}
