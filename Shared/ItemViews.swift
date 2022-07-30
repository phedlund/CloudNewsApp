//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import Nuke
import NukeUI
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
    @ObservedObject var model: ArticleModel

    var body: some View {
        Button {
            Task {
                try? await NewsManager.shared.markRead(items: [model.item!], unread: !model.unread)
            }
        } label: {
            Label {
                Text(model.unread ? "Read" : "Unread")
            } icon: {
                Image(systemName: model.unread ? "eye" : "eye.slash")
            }
        }
        Button {
            Task {
                try? await NewsManager.shared.markStarred(item: model.item!, starred: !model.starred)
            }
        } label: {
            Label {
                Text(model.starred ? "Unstar" : "Star")
            } icon: {
                Image(systemName: model.starred ? "star" : "star.fill")
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
    @AppStorage(StorageKeys.showFavIcons) private var showFavIcons: Bool?
    var nodeIcon: SystemImage

    @ViewBuilder
    var body: some View {
        if showFavIcons ?? true {
#if os(macOS)
            Image(nsImage: nodeIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
#else
            Image(uiImage: nodeIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16, alignment: .center)
#endif
        } else {
            EmptyView()
        }
    }
}

struct FavIconDateAuthorView: View {
    var feedIcon: SystemImage
    var dateAuthorFeed: String
    var textColor: Color
    var itemOpacity: Double
    
    var body: some View {
        HStack {
            ItemFavIconView(nodeIcon: feedIcon)
                .opacity(itemOpacity)
            Text(dateAuthorFeed)
                .font(.subheadline)
                .foregroundColor(textColor)
                .italic()
                .lineLimit(1)
        }
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
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?
    var imageLink: String?
    var size: CGSize
    var itemOpacity: Double

    init(imageLink: String?, size: CGSize, itemOpacity: Double) {
        self.imageLink = imageLink
        self.size = size
        self.itemOpacity = itemOpacity
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
    }

    @ViewBuilder
    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true
        if isShowingThumbnails,
            let imageLink,
            imageLink != "data:null",
            let imageUrl = URL(string: imageLink) {
            LazyImage(url: imageUrl)
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
    var itemOpacity: Double

    @ViewBuilder
    var body: some View {
        VStack {
            if starred {
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 16, height: 16, alignment: .center)
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
        .opacity(itemOpacity)
    }
}
