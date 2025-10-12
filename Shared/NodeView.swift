//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftData
import SwiftUI

struct NodeView: View, Equatable {

    static func == (lhs: NodeView, rhs: NodeView) -> Bool {
        lhs.node == rhs.node
    }

    @Environment(NewsModel.self) private var newsModel

    let node: Node

#if os(iOS)
    let noChildrenPadding = 10.0
    let childrenPadding = -8.0
#else
    let noChildrenPadding = 0.0
    let childrenPadding = 0.0
#endif

    @Query private var favIcons: [FavIcon]

    private var count: Int {
        newsModel.unreadCounts[node.id] ?? 0
    }

    var body: some View {
        HStack {
            Label {
                HStack {
                    Text(node.title)
                        .lineLimit(1)
                    Spacer()
                    badgeView
                        .padding(.trailing, node.id.hasPrefix("dddd_") ? childrenPadding : noChildrenPadding)
                }
                .contentShape(Rectangle())
            } icon: {
                favIconView
            }
            .labelStyle(.titleAndIcon)
            Spacer()
        }
        .task(id: node.id) {
            await newsModel.refreshUnreadCount(for: node)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unreadStateDidChange)) { _ in
            Task {
                await newsModel.refreshUnreadCount(for: node)
            }
        }
    }

    var badgeView: some View {
        HStack {
            if node.errorCount > 0 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            }
            if count > 0 {
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule().fill(.secondary))
            }
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
