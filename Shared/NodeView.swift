//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftUI

struct NodeView: View {
    @EnvironmentObject private var model: FeedTreeModel
    @ObservedObject var node: Node<TreeNode>
    @State var unreadCount = ""

    var body: some View {
        NavigationLink(destination: ItemsView(node: node)
                        .environmentObject(model)) {
            HStack {
                Label {
                    Text(node.title)
                        .lineLimit(1)
                } icon: {
                    FeedFavIconView(nodeType: node.value.nodeType)
                }
                .labelStyle(.titleAndIcon)
                Spacer(minLength: 12)
                Text(node.value.unreadCount)
                    .font(.subheadline)
                    .colorInvert()
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                                    .fill(.gray)
                                    .opacity(node.value.unreadCount.isEmpty ? 0.0 : 1.0))
            }
            .padding(.trailing, node.children?.isEmpty ?? true ? 23 : 0)
        }
        .onReceive(node.$unreadCount) { newUnreadCount in
            unreadCount = newUnreadCount ?? ""
        }
    }
}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
