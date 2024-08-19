//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftData
import SwiftUI

struct NodeView: View {
    @Environment(FeedModel.self) private var feedModel

    let node: NodeStruct

    @State private var isShowingConfirmation = false
    @State private var favIcon: SystemImage?
    @State private var title = "Untitled"

#if os(iOS)
    let noChildrenPadding = 18.0
#else
    let noChildrenPadding = 0.0
#endif

    var body: some View {
        HStack {
            Label {
                Text(node.title)
                    .lineLimit(1)
            } icon: {
                favIconView
            }
            .labelStyle(.titleAndIcon)
            Spacer()
            BadgeView(node: node)
                .padding(.trailing, node.isTopLevel ? 0 : noChildrenPadding)
        }
        .confirmationDialog(
            "Are you sure you want to delete \"\(node.title)\"?",
            isPresented: $isShowingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) {
                withAnimation {
//                   feedModel.delete(node)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("No", role: .cancel) { }
        } message: {
            switch node.nodeType {
            case .empty, .all, .starred:
                EmptyView()
            case .folder(_):
                Text("All feeds and articles in \"\(node.title)\" will also be deleted")
            case .feed(_):
                Text("All articles in \"\(node.title)\" will also be deleted")
            }
        }
    }

}

private extension NodeView {

    var favIconView: some View {
        HStack {
            switch node.nodeType {
            case .all, .empty:
                Image(.rss)
                    .font(.system(size: 18, weight: .light))
            case .starred:
                Image(systemName: "star.fill")
            case .folder( _):
                Image(systemName: "folder")
            case .feed( _):
                AsyncImage(url: node.favIconURL) { image in
                    image.resizable()
                } placeholder: {
                    Image(.rss)
                        .font(.system(size: 18, weight: .light))
                }
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
