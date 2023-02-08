//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

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

    var body: some View {
        Text(title)
            .multilineTextAlignment(.leading)
            .font(font)
        #if os(iOS)
            .foregroundColor(.pbh.whiteText)
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
    var title: String
    var feedId: Int32
    @EnvironmentObject private var favIconRepository: FavIconRepository

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline)
                .italic()
                .lineLimit(1)
        } icon: {
            FavIconView(favIcon: favIconRepository.icons["feed_\(feedId)"] ?? favIconRepository.defaultIcon)
                .environmentObject(favIconRepository)
        }
        .labelStyle(FavIconLabelStyle())
    }
}

struct BodyView: View {
    var displayBody: String

    @ViewBuilder
    var body: some View {
        Text(displayBody)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
#if os(iOS)
            .foregroundColor(.pbh.whiteText)
#endif
    }
}

struct ItemImageView: View {
    var image: SystemImage?
    var size: CGSize

    init(image: SystemImage?, size: CGSize) {
        self.image = image
        self.size = size
    }

    var body: some View {
        VStack {
            if let image {
#if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
#else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
#endif
            } else {
                EmptyView()
            }
        }
    }
}
