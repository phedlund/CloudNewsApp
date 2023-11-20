//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.feedModel) private var feedModel
    @Environment(\.favIconRepository) private var favIconRepository
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNode) private var selectedNode: Node.ID?
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.hideRead) private var hideRead = false

    @Query private var folders: [Folder]
    @Query private var feeds: [Feed]

    @State private var isShowingLogin = false
    @State private var selectedNodeID: Node.ID?
    @State private var selectedItem: String?
    @State private var sortOrder = SortDescriptor(\Item.id)
    @State private var predicate = #Predicate<Item>{ _ in false }

    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $selectedNodeID)
                .environment(feedModel)
                .environment(favIconRepository)
        } detail: {
            ZStack {
                if selectedNodeID != Constants.emptyNodeGuid {
                    ItemsListView(itemSelection: $selectedItem, predicate: predicate, sort: sortOrder)
                        .environment(feedModel)
                        .environment(favIconRepository)
                        .toolbar {
                            ItemListToolbarContent(node: feedModel.currentNode)
                        }
                } else {
                    ContentUnavailableView("No Feed Selected",
                                           image: "rss",
                                           description: Text("Select a feed from the list to display its articles"))
                }
            }
            .navigationTitle(feedModel.currentNode.title)
            .onAppear {
                isShowingLogin = isNewInstall
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                }
            }
        }
        .onChange(of: folders, initial: true) { oldValue, newValue in
            print("Folders changed")
            feedModel.folders = newValue
        }
        .onChange(of: feeds, initial: true) { oldValue, newValue in
            feedModel.feeds = newValue
            favIconRepository.update()
        }
        .onChange(of: selectedNodeID, initial: false) { _, newValue in
            selectedNode = newValue
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
#elseif os(macOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $model.currentNodeID)
                .environmentObject(model)
                .environmentObject(favIconRepository)
        } content: {
            if model.currentNodeID != Constants.emptyNodeGuid {
                let _ = Self._printChanges()
                ItemsListView()
                    .environmentObject(model)
                    .environmentObject(favIconRepository)
                    .toolbar {
                        ItemListToolbarContent(node: model.currentNode)
                    }
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .navigationTitle(model.currentNode.title)
            } else {
                Text("No Feed Selected")
                    .font(.largeTitle).fontWeight(.light)
                    .foregroundColor(.secondary)
            }
        } detail: {
            MacArticleView(item: model.currentItem)
        }
        .onAppear {
            if isNewInstall {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
#endif
    }

    private func updatePredicate() {
        switch NodeType.fromString(typeString: selectedNodeID ?? Constants.emptyNodeGuid) {
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
            if let feedIds = Feed.idsInFolder(folder: id) {
                predicate = #Predicate<Item>{
                    if hideRead {
                        return feedIds.contains($0.feedId) && $0.unread
                    } else {
                        return feedIds.contains($0.feedId)
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
