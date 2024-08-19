//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(FeedModel.self) private var feedModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.hideRead) private var hideRead = false

    @State private var isShowingLogin = false
    @State private var navigationTitle: String?
    @State private var sortOrder = SortDescriptor(\Item.id)
    @State private var predicate = #Predicate<Item>{ _ in false }
    @State private var selectedItem: Item? = nil

    @Query private var feeds: [Feed]
    @Query private var folders: [Folder]
    @Query private var items: [Item]

    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $selectedNode)
                .environment(feedModel)
        } detail: {
            ZStack {
                if selectedNode != nil {
                    ItemsListView(predicate: predicate, sort: sortOrder, selectedItem: $selectedItem)
                        .environment(feedModel)
                        .toolbar {
                            contentViewToolBarContent()
                        }
                } else {
                    ContentUnavailableView {
                        Label("No Feed Selected", image: .rss)
                    } description: {
                        Text("Select a feed from the list to display its articles")
                    }
                }
            }
            .navigationTitle(navigationTitle ?? "Untitled")
            .onAppear {
                Task {
                    let center = UNUserNotificationCenter.current()
                    do {
                        if try await center.requestAuthorization(options: [.badge]) == true {
                            // You have authorization.
                        } else {
                            // You don't have authorization.
                        }
                    } catch {
                        // Handle any errors.
                    }
                }
                isShowingLogin = isNewInstall
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                        .environment(feedModel)
                }
            }
        }
        .accentColor(.accent)
        .navigationSplitViewStyle(.automatic)
        .onChange(of: selectedNode ?? Data(), initial: true) { _, newValue in
            let nodeType = NodeType.fromData(newValue)
            switch nodeType {
            case .empty:
                navigationTitle = ""
            case .all:
                navigationTitle = "All Articles"
            case .starred:
                navigationTitle = "Starred Articles"
            case .folder(let id):
                let folder = folders.first(where: { $0.id == id })
                navigationTitle = folder?.name ?? "Untitled Folder"
            case .feed(let id):
                let feed = feeds.first(where: { $0.id == id })
                navigationTitle = feed?.title ?? "Untitled Feed"
            }
            // TODO           if let node = selectedNode, let model = nodes.first(where: { $0.nodeName == node }) {
            //                feedModel.currentNode = model
            ////                feedModel.updateUnreadCount()
            //            }
            selectedNode = newValue
            updatePredicate()
        }
        .onChange(of: hideRead, initial: true) { _, _ in
            updatePredicate()
        }
        .onChange(of: sortOldestFirst, initial: true) { _, newValue in
            sortOrder = newValue ? SortDescriptor(\Item.id, order: .forward) : SortDescriptor(\Item.id, order: .reverse)
        }
#else
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $selectedNodeID)
                .environment(feedModel)
        } content: {
            if selectedNodeID != Constants.emptyNodeGuid {
                let _ = Self._printChanges()
                ItemsListView(predicate: predicate, sort: sortOrder, selectedItem: $selectedItem)
                    .environment(feedModel)
                    .toolbar {
                        ItemListToolbarContent(node: feedModel.currentNode)
                    }
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .navigationTitle(feedModel.currentNode.title)
            } else {
                ContentUnavailableView {
                    Label("No Feed Selected", image: .rss)
                } description: {
                    Text("Select a feed from the list to display its articles")
                }
            }
        } detail: {
            if let selectedItem {
                MacArticleView(item: selectedItem)
            } else {
                ContentUnavailableView("No Article Selected",
                                       systemImage: "doc.richtext",
                                       description: Text("Select an article from the list to display it"))
            }
        }
        .onAppear {
            if isNewInstall {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .onChange(of: folders, initial: true) { _, newValue in
            feedModel.folders = newValue
        }
        .onChange(of: feeds, initial: true) { _, newValue in
            feedModel.feeds = newValue
        }
        .onChange(of: selectedNodeID, initial: false) { _, newValue in
            selectedNode = newValue
            feedModel.currentNode = feedModel.node(id: newValue ?? Constants.emptyNodeGuid)
            updatePredicate()
        }
        .onChange(of: hideRead, initial: true) { _, _ in
            updatePredicate()
        }
        .onChange(of: sortOldestFirst, initial: true) { _, newValue in
            sortOrder = newValue ? SortDescriptor(\Item.id, order: .forward) : SortDescriptor(\Item.id, order: .reverse)
        }
        .task {
            selectedNodeID = selectedNode
        }
#endif
    }

    private func updatePredicate() {
        if let selectedNode {
            switch NodeType.fromData(selectedNode) {
            case .empty:
                predicate = #Predicate<Item>{ _ in false }
            case .all:
                predicate = #Predicate<Item>{
                    if hideRead {
                        return $0.unread
                    } else {
                        return true
                    }
                }
            case .starred:
                predicate = #Predicate<Item>{ $0.starred }
            case .folder(id:  let id):
                Task {
                    if let feedIds = await feedModel.backgroundModelActor.feedIdsInFolder(folder: id) {
                        predicate = #Predicate<Item>{
                            if hideRead {
                                return feedIds.contains($0.feedId) && $0.unread
                            } else {
                                return feedIds.contains($0.feedId)
                            }
                        }
                    }
                }
            case .feed(id: let id):
                predicate = #Predicate<Item>{
                    if hideRead {
                        return $0.feedId == id && $0.unread
                    } else {
                        return $0.feedId == id
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    func contentViewToolBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            MarkReadButton()
                .environment(feedModel)
        }
    }

//    private func updateNodes() async {
//        return
//        let allNodeModel = Node(title: "All Articles", errorCount: 0, nodeName: Constants.allNodeGuid, isExpanded: false, nodeType: .all, isTopLevel: true)
//        let starredNodeModel = Node(title: "Starred Articles", errorCount: 0, nodeName: Constants.starNodeGuid, isExpanded: false, nodeType: .starred, isTopLevel: true)
//        await feedModel.backgroundModelActor.insert(allNodeModel)
//        await feedModel.backgroundModelActor.insert(starredNodeModel)
//        try? await feedModel.backgroundModelActor.save()
////        let sortDescriptor = SortDescriptor<Folder>(\.id, order: .forward)
//
//        do {
//            for folder in folders {
//                let folderNodeModel = Node(title: folder.name ?? "Untitled Folder", errorCount: 0, nodeName: "cccc_\(String(format: "%03d", folder.id))", isExpanded: folder.opened, nodeType: .folder(id: folder.id), isTopLevel: true)
//
//                var children = [Node]()
//                let folderFeeds = feeds.filter( { $0.folderId == folder.id })
//                for feed in folderFeeds {
//                    let feedNodeModel = Node(title: feed.title ?? "Untitled Feed", errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id), isTopLevel: false)
//                    feedNodeModel.feed = feed
//                    Task {
//                        await feedModel.backgroundModelActor.insert(feedNodeModel)
//                    }
//                    children.append(feedNodeModel)
//                    feed.node = feedNodeModel
//                }
//
//                Task {
//                    await feedModel.backgroundModelActor.insert(folderNodeModel)
//                }
//                folderNodeModel.folder = folder
//                folderNodeModel.children = children
//                folder.node = folderNodeModel
//                try await feedModel.backgroundModelActor.save()
//            }
//
//            let folderFreeFeeds = feeds.filter( { $0.folderId == 0 } )
//            for feed in folderFreeFeeds {
//                let feedNodeModel = Node(title: feed.title ?? "Untitled Feed", errorCount: feed.updateErrorCount, nodeName: "dddd_\(String(format: "%03d", feed.id))", isExpanded: false, nodeType: .feed(id: feed.id), isTopLevel: true)
//                feedNodeModel.feed = feed
//                Task {
//                    await feedModel.backgroundModelActor.insert(feedNodeModel)
//                }
//                feed.node = feedNodeModel
//            }
//            try await feedModel.backgroundModelActor.save()
//        } catch {
//
//        }
//
//    }
}

//struct ContentView_Previews: PreviewProvider {
//    struct Preview: View {
//        @StateObject private var model = FeedModel()
//        @StateObject private var settings = Preferences()
//        var body: some View {
//            ContentView(model: model, settings: settings)
//        }
//    }
//    static var previews: some View {
//        Preview()
//    }
//}
//
