//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import SwiftData
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
    var title: String

    @State private var nodeType = NodeType.empty
    @Query private var feeds: [Feed]

    init(title: String, feedId: Int64) {
        self.title = title
        let predicate = #Predicate<Feed>{ $0.id == feedId }
        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        _feeds = Query(descriptor)
    }

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline)
                .italic()
#if os(iOS)
                .foregroundColor(.pbh.whiteText)
#endif
                .lineLimit(1)
        } icon: {
            FavIconView(nodeType: NodeType.feed(id: feeds.first?.id ?? 0))
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
