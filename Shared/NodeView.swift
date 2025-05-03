//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import Kingfisher
import SwiftData
import SwiftUI

struct NodeView: View {
    @Environment(NewsModel.self) private var newsModel

    let node: Node

    @State private var favIcon: SystemImage?
    @State private var title = "Untitled"
    @State private var unreadCount = 0

#if os(iOS)
    let noChildrenPadding = 10.0
    let childrenPadding = -8.0
#else
    let noChildrenPadding = 0.0
    let childrenPadding = 0.0
#endif

    var body: some View {
        HStack {
            Label {
                HStack {
                    Text(node.title)
                        .lineLimit(1)
                    Spacer()
                    BadgeView(node: node, unreadCount: $unreadCount)
                        .padding(.trailing, node.id.hasPrefix("cccc_") ? childrenPadding : noChildrenPadding)
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

}

private extension NodeView {

    var favIconView: some View {
        HStack {
            switch node.type {
            case .all, .empty:
                Image(.rss)
                    .font(.system(size: 18, weight: .light))
            case .starred:
                Image(systemName: "star.fill")
            case .folder( _):
                Image(systemName: "folder")
            case .feed( _):
                KFImage(node.favIconURL)
                    .placeholder {
                        Image(.rss)
                            .font(.system(size: 18, weight: .light))
                    }
                    .resizable()
                    .frame(width: 22, height: 22)
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
