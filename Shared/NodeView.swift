//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftUI

struct NodeView: View {
    @ObservedObject var node: Node<TreeNode>

    var body: some View {
        NavigationLink(destination: ItemsView(node: node)) {
            HStack {
                node.value.faviconImage
                Text(node.value.title)
                    .lineLimit(1)
                    .font(.subheadline)
                Spacer(minLength: 12)
                Text(node.value.unreadCount)
                    .font(.subheadline)
                    .colorInvert()
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                                    .fill(.gray)
                                    .opacity(node.value.unreadCount.isEmpty ? 0.0 : 1.0))
            }
            .padding(.trailing, node.value.isLeaf ? 23 : 0)
        }
    }
}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
