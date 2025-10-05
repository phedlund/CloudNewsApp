//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftData
import SwiftUI

enum ModalSheet: String {
    case acknowledgement
    case addFeed
    case addFolder
    case login
    case settings
    case feedSettings
}

extension ModalSheet: Identifiable {
    var id: ModalSheet { self }
}

struct SidebarView: View {
    @Environment(NewsModel.self) private var newsModel
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext

#if os(macOS)
    @Environment(\.openWindow) var openWindow
    @AppStorage(SettingKeys.syncInterval) var syncInterval: SyncInterval = .fifteen
    @State private var timerStart = Date.now
    private let syncTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
#endif
    @AppStorage(SettingKeys.isNewInstall) var isNewInstall = true
    @AppStorage(SettingKeys.newsVersion) var newsVersion = ""

    @State private var modalSheet: ModalSheet?
    @State private var isShowingConfirmation = false
    @State private var isShowingError = false
    @State private var isShowingRename = false
    @State private var isShowingAlert = false
    @State private var errorMessage = ""
    @State private var confirmationNode: Node?
    @State private var alertInput = ""

    @Binding var nodeSelection: Data?

    @Query private var folders: [Folder]
    @Query(sort: [SortDescriptor<Feed>(\.id)]) private var feeds: [Feed]
    @Query(
        FetchDescriptor(predicate: #Predicate<Node>{ $0.parent == nil },
                        sortBy: [SortDescriptor<Node>(\.pinned, order: .reverse), SortDescriptor<Node>(\.id)])
    ) private var nodes: [Node]

    init(nodeSelection: Binding<Data?>) {
        self._nodeSelection = nodeSelection
    }

    var body: some View {
        Group {
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
            if nodes.isEmpty {
                ContentUnavailableView {
                    Label("No Feeds Available", image: .rss)
                } description: {
                    Text("Tap the sync button \(Image(systemName: "arrow.clockwise")) to download your feeds. Then select a feed from the sidebar to show its articles.")
                }
            } else {
                List(nodes, id: \.id, children: \.wrappedChildren, selection: $nodeSelection) { node in
                    NodeView(node: node)
                        .environment(newsModel)
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
                                switch detail.type {
                                case .all, .empty, .unread, .starred:
                                    break
                                case .feed(id: _),  .folder(id: _):
                                    Task {
                                        do {
                                            try await newsModel.delete(detail)
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
                            } label: {
                                Text("Delete \(detail.title)")
                            }
                            Button("Cancel", role: .cancel) {
                                confirmationNode = nil
                            }
                        } message: { detail in
                            switch detail.type {
                            case .all, .empty, .unread, .starred:
                                EmptyView()
                            case .feed(id: _):
                                Text("This will delete the feed \(detail.title)")
                            case .folder(id: _):
                                Text("This will delete the folder \(detail.title) and all its feeds")
                            }
                        }
                }
                .listStyle(.automatic)
                .refreshable {
                    sync()
                }
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
#endif
        .toolbar {
            sidebarToolBarContent()
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
        .navigationSubtitle(syncManager.syncState.description)
        .sheet(item: $modalSheet, onDismiss: {
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView()
                        .environment(newsModel)
                }
            case .feedSettings:
                NavigationView {
                    FeedSettingsView()
                        .environment(newsModel)
                }
            case .login:
                NavigationView {
                    SettingsView()
                        .environment(newsModel)
                }
            case .acknowledgement, .addFeed, .addFolder:
                EmptyView()
            }
        })
        .alert(Text($alertInput.wrappedValue), isPresented: $isShowingRename, actions: {
            TextField("Title", text: $alertInput)
            Button("Rename") {
                switch newsModel.currentNodeType {
                case .empty, .all, .unread, .starred, .feed( _):
                    break
                case .folder(let id):
                    Task {
                        await folderRenameAction(folderId: id, newName: alertInput)
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
        .onReceive(NotificationCenter.default.publisher(for: .renameFolder)) { _ in
            switch newsModel.currentNodeType {
            case .empty, .all, .unread, .starred, .feed( _):
                break
            case .folder(let id):
                Task {
                    nodeSelection = newsModel.currentNodeType.asData
                    alertInput = await newsModel.folderName(id: id)
                    isShowingRename = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFolder)) { _ in
            switch newsModel.currentNodeType {
            case .empty, .all, .unread, .starred, .feed( _):
                break
            case .folder(let id):
                if let node = nodes.first(where: { $0.type == .folder(id: id) }) {
                    confirmationNode = node
                    isShowingConfirmation = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFeed)) { _ in
            switch newsModel.currentNodeType {
            case .empty, .all, .unread, .starred, .folder( _):
                break
            case .feed(let id):
                if let node = nodes.first(where: { $0.type == .feed(id: id) }) {
                    confirmationNode = node
                    isShowingConfirmation = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncNews)) { _ in
            sync()
        }
    }

    private func folderRenameAction(folderId: Int64, newName: String) async {
        let nodeType: NodeType = .folder(id: folderId)
        if let node = nodes.first(where: { $0.type == nodeType } ), node.title != newName, let folder = folderForNodeType(nodeType) {
            do {
                try await newsModel.renameFolder(folderId: folderId, to: newName)
                node.title = newName
                folder.name = newName
                try modelContext.save()
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

    private func folderForNodeType(_ nodeType: NodeType) -> Folder? {
        switch nodeType {
        case .empty, .all, .unread, .starred, .feed(_):
            return nil
        case .folder(let id):
            return folders.first(where: { $0.id == id })
        }
    }

    @ViewBuilder
    private func contextMenu(node: Node) -> some View {
        switch node.type {
        case .empty, .starred:
            EmptyView()
        case .all, .unread:
            MarkReadButton(nodeType: node.type)
                .environment(newsModel)
        case .folder( _):
            MarkReadButton(nodeType: node.type)
                .environment(newsModel)
            Button {
                nodeSelection = node.type.asData
                newsModel.currentNodeType = node.type
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
        case .feed( _):
            MarkReadButton(nodeType: node.type)
                .environment(newsModel)
            Button {
                nodeSelection = node.type.asData
                newsModel.currentNodeType = node.type
#if os(macOS)
                openWindow(id: ModalSheet.feedSettings.rawValue)
#else
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
            if syncManager.syncState != .idle {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
#endif
            Button {
                sync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(syncManager.syncState != .idle || isNewInstall)
#if !os(macOS)
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
        case .all, .unread:
            result.predicate = #Predicate<Item>{ $0.unread }
        case .folder(id: let id):
            let feedIds = feeds.filter( { $0.folderId == id }).map( { $0.id } )
            result.predicate = #Predicate<Item>{ feedIds.contains($0.feedId) && $0.unread }
        case .feed(id: let id):
            result.predicate = #Predicate<Item>{  $0.feedId == id && $0.unread }
        }
        return result
    }

    private func sync() {
        Task {
            do {
                if let newsStatus = try await syncManager.sync() {
                    newsVersion = newsStatus.version
                    isShowingError = false
                    if newsStatus.warnings.incorrectDbCharset {
                        errorMessage = NSLocalizedString("The Nextcloud server database charset is not configured properly", comment: "Message that the database on the Nextcloud server is not configured properly")
                        isShowingError = true
                    }
                    if newsStatus.warnings.improperlyConfiguredCron {
                        errorMessage = NSLocalizedString("The cron job on the Nextcloud server is not configured properly", comment: "Message that the Nextcloud server cron job is not configured properly")
                        isShowingError = true
                    }
                }
            } catch {
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
