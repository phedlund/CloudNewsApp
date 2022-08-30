//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftUI

struct NodeView: View {
    @EnvironmentObject private var model: FeedModel
    @ObservedObject var node: Node
    @Binding var selectedFeed: Int
    @Binding var modalSheet: ModalSheet?

    @State private var isShowingFolderRename = false
    @State private var isShowingConfirmation = false
    @State private var icon = SystemImage()

#if os(iOS)
    let noChildrenPadding = 21.0
#else
    let noChildrenPadding = 0.0
#endif

    var body: some View {
        HStack {
            Label {
                Text(node.title)
                    .lineLimit(1)
            } icon: {
#if !os(macOS)
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22, alignment: .center)
#else
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16, alignment: .center)
#endif
            }
            .labelStyle(.titleAndIcon)
            Spacer(minLength: 12)
            BadgeView(unreadCount: node.unreadCount, errorCount: node.errorCount)
        }
        .padding(.trailing, node.children?.isEmpty ?? true ? noChildrenPadding : 0)
        .onAppear {
            switch node.nodeType {
            case .empty, .all:
                icon = SystemImage(named: "rss")!
            case .starred:
                icon = SystemImage(symbolName: "star.fill")!
            case .folder( _):
                icon = SystemImage(symbolName: "folder")!
            case .feed(let id):
                if let feed = CDFeed.feed(id: id) {
                    Task {
                        icon = await FavIconHelper.icon(for: feed)
                    }
                } else {
                    icon = SystemImage(named: "rss")!
                }
            }
        }
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

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
