//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import NukeUI
import SwiftData
import SwiftUI

struct NodeView: View {
    @Environment(FeedModel.self) private var feedModel

    let node: NodeModel

    @State private var isShowingConfirmation = false
    @State private var favIconUrl: URL?
    @State private var title = "Untitled"

#if os(iOS)
    let noChildrenPadding = 18.0
#else
    let noChildrenPadding = 0.0
#endif

    var body: some View {
        LabeledContent {
            BadgeView(node: node, modelContext: feedModel.modelContext)
                .padding(.trailing, node.children?.isEmpty ?? true ? noChildrenPadding : 0)
        } label: {
            Label {
                Text(node.title)
                    .lineLimit(1)
            } icon: {
                favIconView
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
    }

}

private extension NodeView {

    @MainActor
    var favIconView: some View {
        Group {
            switch node.nodeType {
            case .all, .empty:
                Image("rss")
                    .font(.system(size: 18, weight: .light))
            case .starred:
                Image(systemName: "star.fill")
            case .folder( _):
                Image(systemName: "folder")
            case .feed( _):
                LazyImage(url: favIconUrl)  { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        Image("rss")
                            .font(.system(size: 18, weight: .light))
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 22, height: 22)
            }
        }
        .task {
            Task {
                favIconUrl = try await node.feed?.favIconUrl
            }
        }
    }

}
//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
