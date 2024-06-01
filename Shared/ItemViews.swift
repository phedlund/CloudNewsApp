//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import SwiftData
import SwiftUI

struct ItemListToolbarContent: ToolbarContent {
    @Environment(FeedModel.self) private var feedModel
    var node: NodeModel

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            MarkReadButton(node: node)
                .environment(feedModel)
        }
    }
}

struct ContextMenuContent: View {
    @Environment(FeedModel.self) private var feedModel

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
                try? await feedModel.markStarred(item: item, starred: !item.starred)
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

extension View {
    @ViewBuilder
    func labelStyle(includeFavIcon: Bool) -> some View {
        if includeFavIcon {
            self.labelStyle(.titleAndIcon)
        } else {
            self.labelStyle(.titleOnly)
        }
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
