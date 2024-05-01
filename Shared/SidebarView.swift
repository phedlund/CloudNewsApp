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

    @AppStorage(SettingKeys.isNewInstall) var isNewInstall = true

    @State private var modalSheet: ModalSheet?
    @State private var isShowingConfirmation = false
    @State private var isShowingError = false
    @State private var isShowingRename = false
    @State private var isShowingAlert = false
    @State private var errorMessage = ""
    @State private var confirmationNode: Node?
    @State private var alertInput = ""
    @State private var selectedFeed: Int64 = 0

    @Binding var nodeSelection: Node.ID?

    @Query(filter: #Predicate<NodeModel>{ $0.parentItem == nil }, sort: \NodeModel.id, order: .forward) private var nodes: [NodeModel]

    init(nodeSelection: Binding<Node.ID?>) {
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
        List(nodes, id: \.id, children: \.children, selection: $nodeSelection) { node in
            NodeView(node: node)
                .environment(feedModel)
                .tag(node.id)
                .contextMenu {
//                    contextMenu(node: node)
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
        .listStyle(.automatic)
        .accentColor(.pbh.darkIcon)
        .refreshable {
            sync()
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
#endif
        .toolbar(content: sidebarToolBarContent)
        .onReceive(NotificationCenter.default.publisher(for: .deleteFolder)) { _ in
            confirmationNode = feedModel.currentNode
            isShowingConfirmation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameFolder)) { _ in
            confirmationNode = feedModel.currentNode
            alertInput = feedModel.currentNode?.title ?? "Untitled"
            isShowingRename = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFeed)) { _ in
            confirmationNode = feedModel.currentNode
            isShowingConfirmation = true
        }
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
                switch feedModel.currentNode!.nodeType {
                case .empty, .all, .starred, .feed( _):
                    break
                case .folder(let id):
                    if let folder = feedModel.modelContext.folder(id: id), feedModel.currentNode?.title != alertInput {
                        Task {
                            do {
                                try await feedModel.renameFolder(folder: folder, to: alertInput)
                                let node = feedModel.currentNode
                                node?.title = alertInput
                                folder.name = node?.title
                                try NewsData.shared.container?.mainContext.save()
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
//                node.title = alertInput
                isShowingRename = false
            }
        }, message: {
            Text("Rename the folder")
        })
    }

    @ViewBuilder
    private func contextMenu(node: Node) -> some View {
        switch node.nodeType {
        case .empty, .starred:
            EmptyView()
        case .all:
            MarkReadButton(node: node)
                .environment(feedModel)
        case .folder( _):
            MarkReadButton(node: node)
                .environment(feedModel)
            Button {
                nodeSelection = node.id
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
            MarkReadButton(node: node)
                .environment(feedModel)
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.feedSettings.rawValue, value: feedId)
#else
                nodeSelection = node.id
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
                .opacity(newsManager.isSyncing ? 1.0 : 0.0)
                .controlSize(.small)
            Button {
                sync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(newsManager.isSyncing || isNewInstall)
#else
            ProgressView()
                .progressViewStyle(.circular)
                .opacity(feedModel.isSyncing ? 1.0 : 0.0)
            Button {
                sync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(feedModel.isSyncing || isNewInstall)
            Button {
                modalSheet = .settings
            } label: {
                Image(systemName: "ellipsis.circle")
            }
#endif
        }
    }

    private func sync() {
        Task(priority: .userInitiated) {
            do {
                try await feedModel.sync()
                isShowingError = false
                errorMessage = ""
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

//struct SidebarView_Previews: PreviewProvider {
//    static var previews: some View {
//        SidebarView()
//    }
//}
