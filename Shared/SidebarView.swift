//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import Combine

enum ModalSheet: String {
    case login
    case folderRename
    case settings
    case feedSettings
    case addFeed
    case addFolder
}

extension ModalSheet: Identifiable {
    var id: ModalSheet { self }
}

struct SidebarView: View {
#if os(macOS)
    @Environment(\.openWindow) var openWindow
#endif
    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var preferences: Preferences
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0
    @State private var isShowingAddModal = false
    @State private var modalSheet: ModalSheet?
    @State private var isSyncing = false
    @State private var isShowingConfirmation = false
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var confirmationNode: Node?

    @Binding var nodeSelection: Node.ID?

    private var syncPublisher = NotificationCenter.default
        .publisher(for: .syncComplete)
        .receive(on: DispatchQueue.main)

    init(nodeSelection: Binding<Node.ID?>) {
        self._nodeSelection = nodeSelection
    }

    var body: some View {
        List(selection: $nodeSelection) {
            if isShowingError {
                HStack {
                    Text(errorMessage)
                    Button {
                        isShowingError = false
                    } label: {
                        Text("Dismiss")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.75))
                .cornerRadius(10.0)
                .transition(.move(edge: .top))
            }
            OutlineGroup(model.nodes, id: \.id, children: \.children) { node in
                NodeView(node: node, selectedFeed: $selectedFeed, modalSheet: $modalSheet)
                    .tag(node.id)
                    .accentColor(.pbh.whiteIcon)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        nodeSelection = node.id
                    }
                    .contextMenu {
                        contextMenu(node: node)
                    }
                    .confirmationDialog("Delete?", isPresented: $isShowingConfirmation, presenting: confirmationNode) { detail in
                        Button {
                            model.delete(detail)
                        } label: {
                            Text("Delete \(detail.title)")
                        }
                        Button("Cancel", role: .cancel) {
                            confirmationNode = nil
                        }
                    } message: { detail in
                        switch detail.nodeType {
                        case .all, .empty, .starred:
                            EmptyView()
                        case .feed(id: _):
                            Text("This will delete the feed \(detail.title)")
                        case .folder(id: _):
                            Text("This will delete the folder \(detail.title) and all its feeds")
                        }
                    }
            }
        }
        .listStyle(.automatic)
        .accentColor(.pbh.darkIcon)
        .refreshable {
            sync()
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
#endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(isSyncing ? 1.0 : 0.0)
#if os(macOS)
                    .controlSize(.small)
#endif
                Button {
                    sync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isSyncing)
#if !os(macOS)
                Button {
                    modalSheet = .settings
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
#endif
            }
        }
        .onReceive(syncPublisher) { _ in
            isSyncing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFolder)) { _ in
            confirmationNode = model.currentNode
            isShowingConfirmation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFeed)) { _ in
            confirmationNode = model.currentNode
            isShowingConfirmation = true
        }
        .navigationTitle(Text("Feeds"))
        .sheet(item: $modalSheet, onDismiss: {
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView()
                }
            case .folderRename:
                NavigationView {
                    FolderRenameView(selectedFeed)
                }
            case .feedSettings:
                NavigationView {
                    FeedSettingsView(selectedFeed)
                }
            case .login:
                NavigationView {
                    SettingsView()
                }
            case .addFeed, .addFolder:
                EmptyView()
            }
        })
    }

    @ViewBuilder
    private func contextMenu(node: Node) -> some View {
        switch node.nodeType {
        case .empty, .starred:
            EmptyView()
        case .all:
            MarkReadButton(node: node)
        case .folder(let folderId):
            MarkReadButton(node: node)
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.folderRename.rawValue, value: folderId)
#else
                selectedFeed = Int(folderId)
                modalSheet = .folderRename
#endif
            } label: {
                Label("Rename...", systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
                confirmationNode = node
                isShowingConfirmation = true
            } label: {
                Label("Delete...", systemImage: "trash")
            }
        case .feed(let feedId):
            MarkReadButton(node: node)
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.feedSettings.rawValue, value: feedId)
#else
                selectedFeed = Int(feedId)
                modalSheet = .feedSettings
#endif
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            Button(role: .destructive) {
                confirmationNode = node
                isShowingConfirmation = true
            } label: {
                Label("Delete...", systemImage: "trash")
            }
        }
    }

    private func sync() {
        isSyncing = true
        Task(priority: .userInitiated) {
            do {
                try await NewsManager().sync()
                isShowingError = false
                errorMessage = ""
                model.update()
            } catch(let error as PBHError) {
                switch error {
                case .networkError(let message):
                    errorMessage = message
                default:
                    errorMessage = error.localizedDescription
                }
                isShowingError = true
                isSyncing = false
            }
        }
    }
}

//struct SidebarView_Previews: PreviewProvider {
//    static var previews: some View {
//        SidebarView()
//    }
//}
