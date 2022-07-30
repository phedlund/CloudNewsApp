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
    @ObservedObject var model: ArticleModel
    let font = Font.headline.weight(.semibold)

    var body: some View {
        let textColor = model.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(model.item!.title ?? "Untitled")
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
    @ObservedObject var model: ArticleModel

    var body: some View {
        let textColor = model.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        HStack {
            ItemFavIconView(nodeIcon: model.feedIcon)
                .opacity(model.unread ? 1.0 : 0.4)
            Text(model.dateAuthorFeed)
                .font(.subheadline)
                .foregroundColor(textColor)
                .italic()
                .lineLimit(1)
        }
    }
}

struct BodyView: View {
    @ObservedObject var model: ArticleModel

    @ViewBuilder
    var body: some View {
        let textColor = model.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(model.displayBody)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
            .foregroundColor(textColor)
    }
}

struct ItemImageView: View {
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?
    @ObservedObject var model: ArticleModel
    var size: CGSize

    init(model: ArticleModel, size: CGSize) {
        self.model = model
        self.size = size
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
    }

    @ViewBuilder
    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true
        if isShowingThumbnails,
            let imageLink = model.imageLink,
            imageLink != "data:null",
            let imageUrl = URL(string: imageLink) {
            LazyImage(url: imageUrl)
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(model.unread ? 1.0 : 0.4)
        } else {
            Color.pbh.whiteCellBackground
                .frame(width: 2, height: size.height)
        }
    }

}

struct ItemStarredView: View {
    @ObservedObject var model: ArticleModel

    @ViewBuilder
    var body: some View {
        VStack {
            if model.starred {
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 16, height: 16, alignment: .center)
            } else {
                HStack {
                    Spacer()
                }
                .frame(width: 16)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
        .opacity(model.unread ? 1.0 : 0.4)
    }
}
