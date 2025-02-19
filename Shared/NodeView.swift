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
    @Environment(FeedModel.self) private var feedModel

    let node: Node

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
                HStack {
                    Text(node.title)
                        .lineLimit(1)
                    Spacer()
                    BadgeView(node: node)
                        .padding(.trailing, node.parent == nil ? 0 : noChildrenPadding)
                }
                .contentShape(Rectangle())
            } icon: {
                favIconView
            }
            .labelStyle(.titleAndIcon)
            Spacer()
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
            switch node.type {
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
