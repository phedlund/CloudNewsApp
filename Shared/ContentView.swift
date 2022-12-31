//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import Combine
import CoreData
import SwiftUI

struct ContentView: View {
#if !os(macOS)
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    @EnvironmentObject private var model: FeedModel
    @StateObject private var favIconRepository = FavIconRepository()
    @StateObject private var nodeRepository = NodeRepository()
    @Environment(\.managedObjectContext) private var moc
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""

    @State private var isShowingLogin = false
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var selectedItem: NSManagedObjectID?

    private var isNotLoggedIn: Bool {
        return server.isEmpty || username.isEmpty || password.isEmpty
    }

    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $nodeRepository.currentNode)
                .environmentObject(model)
                .environmentObject(favIconRepository)
        } detail: {
            ZStack {
                if nodeRepository.currentNode != EmptyNodeGuid {
                    ArticlesFetchView(nodeRepository: nodeRepository)
                        .environmentObject(favIconRepository)
                        .toolbar {
                            ItemListToolbarContent(node: model.currentNode)
                        }
                } else {
                    Text("No Feed Selected")
                        .font(.largeTitle).fontWeight(.light)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(model.currentNode.title)
            .onAppear {
                isShowingLogin = isNotLoggedIn
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    break
                case .inactive:
                    break
                case .background:
                    appDelegate.scheduleAppRefresh()
                @unknown default:
                    fatalError("Unknown scene phase")
                }
            }
        }
#elseif os(macOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $nodeRepository.currentNode)
                .environmentObject(model)
                .environmentObject(favIconRepository)
        } content: {
            if nodeRepository.currentNode != EmptyNodeGuid {
                let _ = Self._printChanges()
                ArticlesFetchViewMac(nodeRepository: nodeRepository, selectedItem: $selectedItem)
                    .environmentObject(favIconRepository)
                    .toolbar {
                        ItemListToolbarContent(node: model.currentNode)
                    }
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
            } else {
                Text("No Feed Selected")
                    .font(.largeTitle).fontWeight(.light)
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let selectedItem, let item = moc.object(with: selectedItem) as? CDItem {
                MacArticleView(item: item)
            } else {
                Text("No Article Selected")
                    .font(.largeTitle).fontWeight(.light)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if isNotLoggedIn {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .onChange(of: selectedItem) { newValue in
            if let newValue, let item = moc.object(with: newValue) as? CDItem {
                model.updateCurrentItem(item)
            }
        }
#endif
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
