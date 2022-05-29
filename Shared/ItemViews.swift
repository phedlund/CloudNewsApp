//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import Kingfisher
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
    var title: String
    var unread: Bool
    let font = Font.headline.weight(.semibold)

    var body: some View {
        let textColor = unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(title)
            .multilineTextAlignment(.leading)
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true) //force wrapping
    }
}

struct FavIconDateAuthorView: View {
    var dateAuthorFeed: String
    var unread: Bool
    var feedId: Int32

    var body: some View {
        let textColor = unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        HStack {
            ItemFavIconView(nodeType: .feed(id: feedId))
                .opacity(unread ? 1.0 : 0.4)
            Text(dateAuthorFeed)
                .font(.subheadline)
                .foregroundColor(textColor)
                .italic()
                .lineLimit(1)
        }
    }
}

struct BodyView: View {
    var bodyText: String
    var unread: Bool

    @ViewBuilder
    var body: some View {
        let textColor = unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(bodyText)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.body)
            .foregroundColor(textColor)
    }
}

struct ItemImageView: View {
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?
    var imageLink: String?
    var unread: Bool
    var size: CGSize

    @ViewBuilder
    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true

        if isShowingThumbnails, let imageLink = imageLink, let thumbnailURL = URL(withCheck: imageLink) {
            KFImage(thumbnailURL)
                .cancelOnDisappear(true)
                .setProcessors([ResizingImageProcessor(referenceSize: CGSize(width: size.width, height: size.height), mode: .aspectFill),
                                CroppingImageProcessor(size: CGSize(width: size.width, height: size.height), anchor: CGPoint(x: 0.5, y: 0.5)),
                                OverlayImageProcessor(overlay: .white, fraction: unread ? 1.0 : 0.4)])
                .frame(width: size.width, height: size.height)
        } else {
            Spacer(minLength: 2)
        }
    }
}

struct ItemStarredView: View {
    var starred: Bool
    var unread: Bool

    @ViewBuilder
    var body: some View {
        VStack {
            if starred {
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
        .opacity(unread ? 1.0 : 0.4)
    }
}
