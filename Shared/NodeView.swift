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

    @Query private var favIcons: [FavIcon]

    private var count: Int {
        newsModel.unreadCount(for: node)
    }

    var body: some View {
        let badgeView = Text("\(count > 0 ? "\(count)" : "")")
                .monospacedDigit()
                .foregroundColor(node.errorCount > 0 ? .red : .secondary)

        Label {
            Text(node.title)
                .lineLimit(1)
                .badge(badgeView)
        } icon: {
            favIconView
        }
        .labelStyle(.titleAndIcon)
        .task(id: node.id) {
            await newsModel.refreshUnreadCount(for: node)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unreadStateDidChange)) { _ in
            Task {
                await newsModel.refreshUnreadCount(for: node)
            }
        }
    }

    var favIconView: some View {
        Group {
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

