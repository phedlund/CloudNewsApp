//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import BackgroundTasks
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(NewsModel.self) private var newsModel
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openUrl
#endif
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?

    @State private var isShowingLogin = false
    @State private var focusedItemID: PersistentIdentifier? = nil
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var isInitialized = false
    @State var cache = ArticleWebContentCache()

    @Query private var feeds: [Feed]
    @Query private var folders: [Folder]
    @Query private var items: [Item]
    @Query private var nodes: [Node]

    var navigationTitle: String {
        var result = ""
        switch newsModel.currentNodeType {
            case .empty:
                result = ""
            case .all:
            result = Constants.allArticles
            case .unread:
            result = Constants.unreadArticles
            case .starred:
            result = Constants.starredArticles
            case .folder(let id):
                let folder = folders.first(where: { $0.id == id })
                result = folder?.name ?? Constants.untitledFolderName
            case .feed(let id):
                let feed = feeds.first(where: { $0.id == id })
            result = feed?.title ?? Constants.untitledFeedName
            }
        return result
    }

    var body: some View {
#if DEBUG
        let _ = Logger.app.debug("ContentView body")
        let _ = Self._printChanges()
#endif
#if os(iOS)
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            SidebarView(nodeSelection: $selectedNode)
                .environment(newsModel)
                .environment(syncManager)
        } detail: {
            Group {
                if selectedNode != nil {
                    ItemsListView(selectedItemID: $focusedItemID)
                        .environment(newsModel)
                        .environment(syncManager)
                        .onOpenURL { url in
                            print("Open URL: \(url)")
                            processUrl(url)
                        }
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
            .navigationTitle(navigationTitle)
            .onAppear {
                isShowingLogin = isNewInstall
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                        .environment(newsModel)
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .task {
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
            if !isInitialized {
                await newsModel.populateInitialCache(nodes: nodes)
                isInitialized = true
                if let nodeType = NodeType.fromData(selectedNode ?? Data()) {
                    newsModel.currentNodeType = nodeType
                }
            }
        }
        .onChange(of: focusedItemID, initial: true) { oldValue, newValue in
            guard oldValue != nil else {
                return
            }
            guard let newItem = items.first(where: { $0.persistentModelID == newValue }) else {
                return
            }
            newsModel.currentItem = newItem
        }
        .onChange(of: selectedNode ?? Data(), initial: true) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            if let nodeType = NodeType.fromData(newValue) {
                newsModel.currentNodeType = nodeType
                preferredColumn = .detail
            }
        }
#else
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $selectedNode)
                .environment(newsModel)
                .environment(syncManager)
                .onOpenURL { url in
                    let _ = Logger.app.debug("Opening URL \(url)")
                    processUrl(url)
                }
                .focusSection()

        } content: {
            if selectedNode != nil {
                let _ = Self._printChanges()
                ItemsListView(selectedItemID: $focusedItemID)
                    .environment(newsModel)
                    .environment(syncManager)
                    .focusSection()
                    .toolbar {
                        contentViewToolBarContent()
                    }
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .navigationTitle(navigationTitle)
            } else {
                ContentUnavailableView {
                    Label("No Feed Selected", image: .rss)
                } description: {
                    Text("Select a feed from the list to display its articles")
                }
            }
        } detail: {
            if let item = newsModel.currentItem {
                let content = cache.content(for: item, openUrlAction: openUrl)
                ArticleViewMac(content: content)
                    .environment(newsModel)
                    .focusSection()
            } else {
                ContentUnavailableView("No Article Selected",
                                       systemImage: "doc.richtext",
                                       description: Text("Select an article from the list to display it"))
            }
        }
        .onAppear {
            NSWindow.allowsAutomaticWindowTabbing = false
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
            if isNewInstall {
                openSettings()
            }
        }
        .onChange(of: selectedNode ?? Data(), initial: true) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            if let nodeType = NodeType.fromData(newValue) {
                newsModel.currentNodeType = nodeType
                preferredColumn = .detail
            }
        }
        .onChange(of: focusedItemID, { oldValue, newValue in
            guard let newItem = items.first(where: { $0.persistentModelID == focusedItemID })
            else { return }

            newsModel.currentItem = newItem
            Task {
                await newsModel.markItemsRead(items: [newItem])
            }
        })
#endif
    }

    private func processUrl(_ url: URL) {
        Logger.app.debug(">>> processUrl \(url)")
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                let queryDictionary = queryItems.reduce(into: [String: String]()) { result, item in
                    result[item.name] = item.value
                }
                if let feedIdString = queryDictionary["feedId"],
                   let feedId = Int64(feedIdString) {
                    selectedNode = NodeType.feed(id: feedId).asData
                    if let itemIdString = queryDictionary["id"],
                       let itemId = Int64(itemIdString) {
                        newsModel.navigationItemId = itemId
                    }
                }
                print("Query items: \(queryDictionary)")
            } else {
                selectedNode = NodeType.all.asData
            }
        }
    }

    @ToolbarContentBuilder
    func contentViewToolBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            MarkReadButton()
                .environment(newsModel)
        }
    }

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

