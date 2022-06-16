//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import Nuke
import NukeUI
import SwiftUI

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

struct FavIconDateAuthorView: View {
    @ObservedObject var model: ArticleModel

    var body: some View {
        let textColor = model.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        HStack {
            ItemFavIconView(nodeType: .feed(id: model.feedId))
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
        if isShowingThumbnails, let image = model.image {
            Image(image)
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(model.unread ? 1.0 : 0.4)
        } else {
            Color.pbh.whiteCellBackground
                .frame(width: 2, height: size.height)
                .onAppear {
                    updateImageLink()
                }
        }
    }

    private func updateImageLink() {
        Task {
            guard let currentLink = model.item?.imageLink, currentLink != "data:null" else {
                return
            }
            try await CDItem.addImageLink(item: model.item!, imageLink: "data:null")
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
