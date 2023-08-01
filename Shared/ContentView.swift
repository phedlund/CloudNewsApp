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
    @Environment(\.feedModel) private var model
    @Environment(\.favIconRepository) private var favIconRepository
    @Environment(\.managedObjectContext) private var moc
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNode) private var selectedNodeID: Node.ID?

    @State private var isShowingLogin = false

    private var selection: Binding<Node.ID?> {
        Binding(get: { selectedNodeID }, set: { selectedNodeID = $0 ?? "" })
    }

//    private var selectedNode: Binding<Node> {
//        feedModel[selection.wrappedValue]
//    }


    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: selection)
                .environment(model)
                .environment(favIconRepository)
        } detail: {
            ZStack {
                if model.currentNodeID != Constants.emptyNodeGuid {
                    ItemsListView()
                        .environment(model)
                        .environment(favIconRepository)
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
                isShowingLogin = isNewInstall
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                }
            }
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
