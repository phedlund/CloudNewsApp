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
    @ObservedObject var item: CDItem
    let font = Font.headline.weight(.semibold)

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(item.title ?? "Untitled")
            .multilineTextAlignment(.leading)
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true) //force wrapping
    }
}

struct FavIconDateAuthorView: View {
    @ObservedObject var item: CDItem

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        HStack {
            ItemFavIconView(nodeType: .feed(id: item.feedId))
                .opacity(item.unread ? 1.0 : 0.4)
            Text(item.dateAuthorFeed)
                .font(.subheadline)
                .foregroundColor(textColor)
                .italic()
                .lineLimit(1)
        }
    }
}

struct BodyView: View {
    @ObservedObject var item: CDItem

    @ViewBuilder
    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(item.displayBody ?? "")
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
            .foregroundColor(textColor)
    }
}

struct ItemImageView: View {
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?
    @ObservedObject var item: CDItem
    var size: CGSize

    init(item: CDItem, size: CGSize) {
        self.item = item
        self.size = size
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
    }

    @ViewBuilder
    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true
        if isShowingThumbnails, let imageLink = item.imageLink, imageLink != "data:null", let url = URL(string: imageLink) {
                let request = ImageRequest.init(urlRequest: URLRequest(url: url), processors: [SizeProcessor(), ImageProcessors.Resize(size: size,
                                                                                                                               unit: .points,
                                                                                                                               contentMode: .aspectFill,
                                                                                                                               crop: true,
                                                                                                                               upscale: true)],
                                                priority: .veryHigh,
                                                options: [],
                                                userInfo: nil)

                LazyImage(source: request) { state in
                    if let image = state.image {
                        image
                            .animation(nil, value: true)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .clipped()
                            .opacity(item.unread ? 1.0 : 0.4)
                    } else if state.error != nil {
                        Color.pbh.whiteCellBackground
                            .animation(.none)
                            .frame(width: 2, height: size.height)
                            .onAppear {
                                updateImageLink()
                            }
                    } else {
                        HStack(alignment: .center) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        }
                        .frame(width: size.width, height: size.height)
                    }
                }
            } else {
                Spacer(minLength: 2)
            }
    }

    private func updateImageLink() {
        Task {
            try await CDItem.addImageLink(item: item, imageLink: "data:null")
        }
    }
}

struct ItemStarredView: View {
    @ObservedObject var item: CDItem

    @ViewBuilder
    var body: some View {
        VStack {
            if item.starred {
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
        .opacity(item.unread ? 1.0 : 0.4)
    }
}
