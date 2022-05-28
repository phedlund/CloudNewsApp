//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftUI

struct NodeView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject private var model: FeedModel
    @ObservedObject var node: Node
    @Binding var selectedFeed: Int
    @Binding var modalSheet: ModalSheet?

    @State private var isShowingFolderRename = false
    @State private var isShowingConfirmation = false
    @State private var unreadCount = 0
    @State private var title = ""

    var body: some View {
        HStack {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
#if !os(macOS)
                Image(uiImage: node.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22, alignment: .center)
#else
                Image(nsImage: node.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16, alignment: .center)
#endif
            }
            .labelStyle(.titleAndIcon)
            Spacer(minLength: 12)
            BadgeView(node: node)
        }
#if !os(macOS)
        .padding(.trailing, node.children?.isEmpty ?? true ? 23 : 0)
#endif
        .contextMenu {
            switch node.nodeType {
            case .all, .starred:
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
        .onReceive(node.$unreadCount) { [unreadCount] newUnreadCount in
            self.unreadCount = newUnreadCount
            if node.nodeType == .all, unreadCount != newUnreadCount {
                appDelegate.updateBadge(newUnreadCount)
            }
        }
        .onReceive(node.$title) {
            title = $0
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
            case .all, .starred:
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
