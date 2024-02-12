//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import SwiftUI

struct ItemListToolbarContent: ToolbarContent {
    var node: Node

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            MarkReadButton(node: node)
        }
    }
}

struct ContextMenuContent: View {
    @Environment(\.feedModel) private var feedModel

    var item: Item

    var body: some View {
        Button {
            feedModel.toggleItemRead(item: item)
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
    @Environment(\.favIconRepository) private var favIconRepository

    var title: String
    var feedId: Int64

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline)
                .italic()
                .lineLimit(1)
        } icon: {
            FavIconView(favIcon: favIconRepository.icons["feed_\(feedId)"] ?? favIconRepository.defaultIcon)
                .environment(favIconRepository)
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

extension Image {

    func imageStyle(size: CGSize) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }

}
