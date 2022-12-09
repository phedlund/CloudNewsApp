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
    @State private var isMarkAllReadDisabled = true

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

    var body: some View {
        Text(title)
            .multilineTextAlignment(.leading)
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true) //force wrapping
    }
}

struct ItemFavIconView: View {
    var nodeIcon: String?
    
    @ViewBuilder
    var body: some View {
        KFImage(URL(string: nodeIcon ?? "data:null"))
            .placeholder {
#if os(macOS)
                Image(nsImage: SystemImage(named: "rss")!)
#else
                Image(uiImage: SystemImage(named: "rss")!)
#endif
            }
            .retry(maxCount: 3, interval: .seconds(5))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 22, height: 22)
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
    var feedIcon: String?
    var dateAuthorFeed: String
    var itemOpacity: Double
    
    var body: some View {
        Label {
            Text(dateAuthorFeed)
                .font(.subheadline)
                .italic()
                .lineLimit(1)
        } icon: {
            ItemFavIconView(nodeIcon: feedIcon)
        }
        .labelStyle(FavIconLabelStyle())
        .opacity(itemOpacity)
    }
}

struct BodyView: View {
    var displayBody: String
    var textColor: Color

    @ViewBuilder
    var body: some View {
        Text(displayBody)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
            .foregroundColor(textColor)
    }
}

struct ItemImageView: View {
    @AppStorage(SettingKeys.showThumbnails) private var showThumbnails: Bool?
    var imageUrl: URL?
    var size: CGSize
    var itemOpacity: Double

    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true
        if isShowingThumbnails,
            let imageUrl {
            KFImage(imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(itemOpacity)
        } else {
            Color.pbh.whiteCellBackground
                .frame(width: 2, height: size.height)
        }
    }
}

struct ItemStarredView: View {
    var starred: Bool
    var textColor: Color

    @ViewBuilder
    var body: some View {
        VStack {
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
