//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import Kingfisher
import SwiftUI

struct TitleView: View {
    var item: CDItem

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(item.displayTitle)
            .multilineTextAlignment(.leading)
            .font(.headline)
            .foregroundColor(textColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true) //force wrapping
    }
}

struct FavIconDateAuthorView: View {
    var item: CDItem

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        HStack {
            ItemFavIconView(item: item)
            Text(item.dateAuthorFeed)
                .font(.subheadline)
                .foregroundColor(textColor)
                .italic()
                .lineLimit(1)
        }
    }
}

struct BodyView: View {
    var item: CDItem

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        Text(item.displayBody)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .font(.subheadline)
            .foregroundColor(textColor)
    }
}

struct ItemImageView: View {
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?

    var item: CDItem
    var size: CGSize

    @ViewBuilder
    var body: some View {
        let isShowingThumbnails = showThumbnails ?? true

        if isShowingThumbnails, let imageLink = item.imageLink, let thumbnailURL = URL(string: imageLink) {
            KFImage(thumbnailURL)
                .cancelOnDisappear(true)
                .setProcessors([ResizingImageProcessor(referenceSize: CGSize(width: size.width, height: size.height), mode: .aspectFill),
                                CroppingImageProcessor(size: CGSize(width: size.width, height: size.height), anchor: CGPoint(x: 0.5, y: 0.5)),
                                OverlayImageProcessor(overlay: .white, fraction: item.unread ? 1.0 : 0.4)])
        } else {
            Spacer(minLength: 2)
        }
    }
}

struct ItemStarredView: View {

    var item: CDItem

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
    }
}
