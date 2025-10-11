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
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openUrl
#endif
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?

    @State private var isShowingLogin = false
    @State private var navigationTitle: String?
    @State private var selectedItem: Item? = nil
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar

    @Query private var feeds: [Feed]
    @Query private var folders: [Folder]
    @Query private var nodes: [Node]

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
                    ItemsListView(selectedItem: $selectedItem)
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
                        .environment(newsModel)
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .onChange(of: selectedNode ?? Data(), initial: true) { _, newValue in
            if let nodeType = NodeType.fromData(newValue) {
                newsModel.currentNodeType = nodeType
                switch nodeType {
                case .empty:
                    navigationTitle = ""
                case .all:
                    navigationTitle = "All Articles"
                case .unread:
                    navigationTitle = "Unread Articles"
                case .starred:
                    navigationTitle = "Starred Articles"
                case .folder(let id):
                    let folder = folders.first(where: { $0.id == id })
                    navigationTitle = folder?.name ?? Constants.untitledFolderName
                case .feed(let id):
                    let feed = feeds.first(where: { $0.id == id })
                    navigationTitle = feed?.title ?? "Untitled Feed"
                }
                preferredColumn = .detail
            }
        }
        .onChange(of: selectedItem, initial: true) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            newsModel.currentItem = newValue
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

        } content: {
            if selectedNode != nil {
                let _ = Self._printChanges()
                ItemsListView(selectedItem: $selectedItem)
                    .environment(newsModel)
                    .environment(syncManager)
                    .toolbar {
                        contentViewToolBarContent()
                    }
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .navigationTitle(navigationTitle ?? "Untitled")
            } else {
                ContentUnavailableView {
                    Label("No Feed Selected", image: .rss)
                } description: {
                    Text("Select a feed from the list to display its articles")
                }
            }
        } detail: {
            if let item = newsModel.currentItem {
                ArticleViewMac(content: ArticleWebContent(item: item, openUrlAction: openUrl))
                    .environment(newsModel)
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
        .onChange(of: selectedNode ?? Data(), initial: true) { _, newValue in
            Logger.app.debug("Got new node selection: \(newValue)")
            if let nodeType = NodeType.fromData(newValue) {
                newsModel.currentNodeType = nodeType
                switch nodeType {
                case .empty:
                    navigationTitle = ""
                case .all:
                    navigationTitle = "All Articles"
                case .unread:
                    navigationTitle = "Unread Articles"
                case .starred:
                    navigationTitle = "Starred Articles"
                case .folder(let id):
                    let folder = folders.first(where: { $0.id == id })
                    navigationTitle = folder?.name ?? Constants.untitledFolderName
                case .feed(let id):
                    let feed = feeds.first(where: { $0.id == id })
                    navigationTitle = feed?.title ?? "Untitled Feed"
                }
                preferredColumn = .detail
            }
        }
        .onChange(of: selectedItem, initial: true) { _, newValue in
            newsModel.currentItem = newValue
            if let newValue {
                Task {
                    await newsModel.markItemsRead(items: [newValue])
                }
            }
        }
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
