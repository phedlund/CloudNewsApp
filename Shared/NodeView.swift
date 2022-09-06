//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import Kingfisher
import SwiftUI

struct NodeView: View {
    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var favIconRepository: FavIconRepository
    @ObservedObject var node: Node
    @Binding var selectedFeed: Int
    @Binding var modalSheet: ModalSheet?

    @State private var isShowingFolderRename = false
    @State private var isShowingConfirmation = false

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
                NodeFavIconView(node: node)
                    .environmentObject(favIconRepository)
            }
            .labelStyle(.titleAndIcon)
            Spacer(minLength: 12)
            BadgeView(unreadCount: node.unreadCount, errorCount: node.errorCount)
        }
        .padding(.trailing, node.children?.isEmpty ?? true ? noChildrenPadding : 0)
        .contextMenu {
            switch node.nodeType {
            case .empty, .all, .starred:
                EmptyView()
            case .folder(let folderId):
                Button {
                    selectedFeed = Int(folderId)
                    modalSheet = .folderRename
                } label: {
                    Label("Rename...", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    isShowingConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            case .feed(let feedId):
                Button {
                    selectedFeed = Int(feedId)
                    modalSheet = .feedSettings
                } label: {
                    Label("Settings...", systemImage: "gearshape")
                }
                Button(role: .destructive) {
                    isShowingConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete \"\(node.title)\"?",
            isPresented: $isShowingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) {
                withAnimation {
                    model.delete(node)
                }
            }.keyboardShortcut(.defaultAction)
            Button("No", role: .cancel) {}
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

struct NodeFavIconView: View {
    @ObservedObject var node: Node
    @EnvironmentObject private var favIconRepository: FavIconRepository

    @ViewBuilder
    var body: some View {
        VStack {
            KFImage(URL(string: favIconRepository.icons.value[node.nodeType] ?? "data:null"))
                .placeholder { _ in
                    switch node.nodeType {
                    case .all, .empty:
#if os(macOS)
                        Image(nsImage: SystemImage(named: "rss")!)
#else
                        Image(uiImage: SystemImage(named: "rss")!)
#endif
                    case .starred:
                        Image(systemName: "star.fill")
                    case .folder(id: _):
                        Image(systemName: "folder")
                    case .feed(id: _):
                        Color.gray.opacity(0.25)
                    }
                }
                .retry(maxCount: 3, interval: .seconds(5))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
        }
    }
}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
