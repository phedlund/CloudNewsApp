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
    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var nodeRepository: NodeRepository
    @StateObject private var favIconRepository = FavIconRepository()
    @Environment(\.managedObjectContext) private var moc
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""

    @State private var isShowingLogin = false

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
            .navigationTitle(model.nodes.first(where: { $0.id == nodeRepository.currentNode })?.title ?? "Untitled")
            .onAppear {
                isShowingLogin = isNotLoggedIn
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
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
                ArticlesFetchViewMac(nodeRepository: nodeRepository)
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
            MacArticleView(selectedItem: nodeRepository.currentItem)
        }
        .onAppear {
            if isNotLoggedIn {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .onChange(of: nodeRepository.currentItem) { newValue in
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
