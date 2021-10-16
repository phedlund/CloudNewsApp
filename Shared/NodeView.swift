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
    @Binding var selectedFeed: Int
    @Binding var modalSheet: ModalSheet?
    @Binding var isShowingSheet: Bool

    @State private var isShowingFolderRename = false
    @State private var unreadCount = ""

    var body: some View {
        GeometryReader { geometry in
            NavigationLink(destination: ItemsView(node: node)
                            .environmentObject(model)) {
                HStack {
                    Label {
                        Text(node.title)
                            .lineLimit(1)
                    } icon: {
                        FeedFavIconView(nodeType: node.nodeType)
                    }
                    .labelStyle(.titleAndIcon)
                    Spacer(minLength: 12)
                    Text(node.unreadCount)
                        .font(.subheadline)
                        .colorInvert()
                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                        .background(Capsule()
                                        .fill(.gray)
                                        .opacity(node.unreadCount.isEmpty ? 0.0 : 1.0))
                }
                .padding(.trailing, node.children.isEmpty ? 23 : 0)
                .contextMenu {
                    switch node.value.nodeType {
                    case .all, .starred:
                        EmptyView()
                    case .folder(let folderId):
                        Button {
                            selectedFeed = Int(folderId)
                            isShowingFolderRename = true
                        } label: {
                            Label("Rename...", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            //
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(true)
                    case .feed(let feedId):
                        Button {
                            selectedFeed = Int(feedId)
                            modalSheet = .feedSettings
                            isShowingSheet = true
                        } label: {
                            Label("Settings...", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            //
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(true)
                    }
                }
                .onReceive(node.$unreadCount) { newUnreadCount in
                    unreadCount = newUnreadCount
                }
                .popover(isPresented: $isShowingFolderRename) {
                    FolderRenameView(showModal: $isShowingFolderRename)
                }
            }
        }
    }
}

//struct NodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView()
//    }
//}
