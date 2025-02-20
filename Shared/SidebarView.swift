//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftData
import SwiftUI

enum ModalSheet: String {
    case login
    case folderRename
    case settings
    case feedSettings
    case addFeed
    case addFolder
    case acknowledgement
}

extension ModalSheet: Identifiable {
    var id: ModalSheet { self }
}

struct SidebarView: View {
#if os(macOS)
    @Environment(\.openWindow) var openWindow
    @AppStorage(SettingKeys.syncInterval) var syncInterval: SyncInterval = .fifteen
    @State private var timerStart = Date.now
    private let syncTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
#endif
    @Environment(FeedModel.self) private var feedModel
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingKeys.isNewInstall) var isNewInstall = true

    @AppStorage("SelectedNode") var selectedNode: String?

    @State private var modalSheet: ModalSheet?
    @State private var isShowingConfirmation = false
    @State private var isShowingError = false
    @State private var isShowingRename = false
    @State private var isShowingAlert = false
    @State private var errorMessage = ""
    @State private var confirmationNode: Node?
    @State private var alertInput = ""
    @State private var selectedFeed: Int64 = 0
    @State private var unreadPredicate = #Predicate<Item>{ _ in false }

    @Binding var nodeSelection: Data?

    @Query private var folders: [Folder]
    @Query(sort: [SortDescriptor<Feed>(\.id)]) private var feeds: [Feed]
    @Query(filter: #Predicate<Node>{ $0.parent == nil }, sort: \.id) private var nodes: [Node]

    init(nodeSelection: Binding<Data?>) {
        self._nodeSelection = nodeSelection
    }

    var body: some View {
        if isShowingError {
            HStack {
                Spacer(minLength: 10.0)
                HStack {
                    Text(errorMessage)
                        .colorInvert()
                    Spacer()
                    Button {
                        isShowingError = false
                    } label: {
                        Text("Dismiss")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.all, 10.0)
                .background(Color.red.opacity(0.95))
                .cornerRadius(6.0)
                .transition(.move(edge: .top))
                Spacer(minLength: 10.0)
            }
        }
        List(nodes, id: \.id, children: \.wrappedChildren, selection: $nodeSelection) { node in
            NodeView(node: node)
                .environment(feedModel)
                .tag(node.type.asData)
                .contentShape(Rectangle())
                .onTapGesture {
                    nodeSelection = node.type.asData
                }
                .contextMenu {
                    contextMenu(node: node)
                }
                .confirmationDialog("Delete?", isPresented: $isShowingConfirmation, presenting: confirmationNode) { detail in
                    Button(role: .destructive) {
                        feedModel.delete(detail)
                    } label: {
                        Text("Delete \(detail.title)")
                    }
                    Button("Cancel", role: .cancel) {
                        confirmationNode = nil
                    }
                } message: { detail in
                    switch detail.type {
                    case .all, .empty, .starred:
                        EmptyView()
                    case .feed(id: _):
                        Text("This will delete the feed \(detail.title)")
                    case .folder(id: _):
                        Text("This will delete the folder \(detail.title) and all its feeds")
                    }
                }
        }
        .listStyle(.automatic)
//        .accentColor(.phDarkIcon)
        .refreshable {
            await syncManager.sync()
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
#endif
        .toolbar(content: sidebarToolBarContent)
#if os(macOS)
        .onReceive(syncTimer) { _ in
            if syncInterval.rawValue > .zero {
                if Date.now.timeIntervalSince(timerStart) > TimeInterval(syncInterval.rawValue) {
                    timerStart = Date.now
                    sync()
                }
            }
        }
#endif
        .navigationTitle(Text("Feeds"))
        .sheet(item: $modalSheet, onDismiss: {
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView()
                }
            case .feedSettings:
                NavigationView {
                    FeedSettingsView()
                        .environment(feedModel)
                }
            case .login:
                NavigationView {
                    SettingsView()
                }
            case .addFeed, .addFolder, .folderRename, .acknowledgement:
                EmptyView()
            }
        })
        .alert(Text(feedModel.currentNode?.title ?? "Untitled"), isPresented: $isShowingRename, actions: {
            TextField("Title", text: $alertInput)
            Button("Rename") {
                switch feedModel.currentNode!.type {
                case .empty, .all, .starred, .feed( _):
                    break
                case .folder(let id):
                    if let folder = folders.first(where: { $0.id == id }), feedModel.currentNode?.title != alertInput {
                        Task {
                            do {
                                try await feedModel.renameFolder(folder: folder, to: alertInput)
                                let node = feedModel.currentNode
                                node?.title = alertInput
                                folder.name = node?.title
                                try await feedModel.databaseActor.save()
                            } catch let error as NetworkError {
                                errorMessage = error.localizedDescription
                                isShowingError = true
                            } catch let error as DatabaseError {
                                errorMessage = error.localizedDescription
                                isShowingError = true
                            } catch let error {
                                errorMessage = error.localizedDescription
                                isShowingError = true
                            }
                        }
                    }
                }
                isShowingRename = false
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                isShowingRename = false
            }
        }, message: {
            Text("Rename the folder")
        })
    }

    @ViewBuilder
    private func contextMenu(node: Node) -> some View {
        switch node.type {
        case .empty, .starred:
            EmptyView()
        case .all:
            MarkReadButton(fetchDescriptor: unreadFetchDescriptor(node: node))
                .environment(feedModel)
        case .folder( _):
            MarkReadButton(fetchDescriptor: unreadFetchDescriptor(node: node))
                .environment(feedModel)
            Button {
                nodeSelection = node.type.asData
                feedModel.currentNode = node
                alertInput = node.title
                isShowingRename = true
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
            MarkReadButton(fetchDescriptor: unreadFetchDescriptor(node: node))
                .environment(feedModel)
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.feedSettings.rawValue, value: feedId)
#else
                nodeSelection = node.type.asData
                feedModel.currentNode = node
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

    @ToolbarContentBuilder
    func sidebarToolBarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
#if os(macOS)
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .opacity(isSyncing ? 1.0 : 0.0)
                .controlSize(.small)
            Button {
                sync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isSyncing || isNewInstall)
#else
            ProgressView()
                .progressViewStyle(.circular)
                .opacity(syncManager.syncManagerReader.isSyncing ? 1.0 : 0.0)
            Button {
                Task.detached(priority: .background) {
                    await syncManager.sync()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(syncManager.syncManagerReader.isSyncing || isNewInstall)
            Button {
                modalSheet = .settings
            } label: {
                Image(systemName: "ellipsis.circle")
            }
#endif
        }
    }

    private func unreadFetchDescriptor(node: Node) -> FetchDescriptor<Item> {
        var result = FetchDescriptor<Item>()
        switch node.type {
        case .empty, .starred:
            result.predicate = #Predicate<Item>{ _ in false }
        case .all:
            result.predicate = #Predicate<Item>{ $0.unread }
        case .folder(id: let id):
            let feedIds = feeds.filter( { $0.folderId == id }).map( { $0.id } )
            result.predicate = #Predicate<Item>{ feedIds.contains($0.feedId) && $0.unread }
        case .feed(id: let id):
            result.predicate = #Predicate<Item>{  $0.feedId == id && $0.unread }
        }
        return result
    }

}

//struct SidebarView_Previews: PreviewProvider {
//    static var previews: some View {
//        SidebarView()
//    }
//}
