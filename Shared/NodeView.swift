//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftData
import SwiftUI

struct NodeView: View {
    @Environment(NewsModel.self) private var newsModel

    let node: Node

    @State private var unreadCount = 0

#if os(iOS)
    let noChildrenPadding = 10.0
    let childrenPadding = -8.0
#else
    let noChildrenPadding = 0.0
    let childrenPadding = 0.0
#endif

    @Query private var favIcons: [FavIcon]

    var body: some View {
        HStack {
            Label {
                HStack {
                    Text(node.title)
                        .lineLimit(1)
                    Spacer()
                    BadgeView(node: node, unreadCount: $unreadCount)
                        .padding(.trailing, node.id.hasPrefix("dddd_") ? childrenPadding : noChildrenPadding)
                }
                .contentShape(Rectangle())
            } icon: {
                favIconView
            }
            .labelStyle(.titleAndIcon)
            Spacer()
        }
        .onChange(of: unreadCount, initial: true) { _, newValue in
            newsModel.unreadCounts[node.type] = newValue
        }
    }

    var favIconView: some View {
        HStack {
            switch node.type {
            case .all, .empty:
                Image(.rss)
                    .font(.system(size: 18, weight: .light))
            case .unread:
                Image(systemName: "eye.slash")
            case .starred:
                Image(systemName: "star.fill")
            case .folder( _):
                Image(systemName: "folder")
            case .feed(id: let id):
                if let favicon = favIcons.first(where: { $0.id == id }),
                   let data = favicon.icon,
                   let uiImage = SystemImage(data: data) {
#if os(macOS)
                    Image(nsImage: uiImage)
                        .resizable()
                        .frame(width: 22, height: 22)
#else
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 22, height: 22)
#endif
                } else {
                    Image(.rss)
                        .font(.system(size: 18, weight: .light))
                }
            }
        }
        .frame(width: 22, height: 22)
    }

}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
