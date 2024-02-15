//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftData
import SwiftUI

struct NodeView: View {
    @Environment(\.feedModel) private var feedModel
    @State private var isShowingConfirmation = false
    @State private var favIcon = SystemImage()

    var node: Node

#if os(iOS)
    let noChildrenPadding = 18.0
#else
    let noChildrenPadding = 0.0
#endif

    var body: some View {
        LabeledContent {
            BadgeView(node: node)
                .padding(.trailing, node.children?.isEmpty ?? true ? noChildrenPadding : 0)
        } label: {
            Label {
                Text(node.title)
                    .lineLimit(1)
            } icon: {
                FavIconView(favIcon: favIcon)
            }
            .labelStyle(.titleAndIcon)
        }
        .confirmationDialog(
            "Are you sure you want to delete \"\(node.title)\"?",
            isPresented: $isShowingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) {
                withAnimation {
                   feedModel.delete(node)
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
        .task {
            updateFavIcon()
        }

    }

    private func updateFavIcon() {
        switch node.nodeType {
        case .all, .empty:
            favIcon = SystemImage(named: "rss") ?? SystemImage()
        case .starred:
            favIcon = SystemImage(symbolName: "star.fill") ?? SystemImage()
        case .folder( _):
            favIcon = SystemImage(symbolName: "folder") ?? SystemImage()
        case .feed(let id):
            Task {
                favIcon = try await Feed.feed(id: id)?.favIcon ?? SystemImage()
            }
        }
    }

}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
