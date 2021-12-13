//
//  NodeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/21.
//

import SwiftUI

struct NodeView<Content: View> : View {
    @ObservedObject var node: Node
    @Binding var selectedFeed: Int
    @Binding var modalSheet: ModalSheet?
    @Binding var isShowingSheet: Bool
    let model: FeedModel

    @State private var isShowingFolderRename = false
    @State private var isShowingConfirmation = false
    @State private var unreadCount = 0
    @State private var title = ""

    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            NavigationLink(destination: content) {
                HStack {
                    Label {
                        Text(title)
                            .lineLimit(1)
                    } icon: {
                        Image(uiImage: node.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22, alignment: .center)
                    }
                    .labelStyle(.titleAndIcon)
                    Spacer(minLength: 12)
                    BadgeView(text: unreadCount > 0 ? "\(unreadCount)" : "")
                }
            }
        }
        .padding(.trailing, node.children.isEmpty ? 23 : 0)
        .contextMenu {
            switch node.nodeType {
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
                    isShowingConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            case .feed(let feedId):
                Button {
                    selectedFeed = Int(feedId)
                    modalSheet = .feedSettings
                    isShowingSheet = true
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
        .onReceive(node.$unreadCount) {
            unreadCount = $0
        }
        .onReceive(node.$title) {
            title = $0
        }
        .popover(isPresented: $isShowingFolderRename) {
            FolderRenameView(showModal: $isShowingFolderRename)
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

struct BadgeView: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .colorInvert()
            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            .background(Capsule()
                            .fill(.gray)
                            .opacity(text.isEmpty ? 0.0 : 1.0))    }
}
