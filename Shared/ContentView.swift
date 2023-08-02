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
    @AppStorage(SettingKeys.selectedNode) private var selectedNodeID: Node.ID?
    @AppStorage(SettingKeys.selectedItem) private var selectedItem: Data?

    @Query private var folders: [Folder]
    @Query private var feeds: [Feed]

    @State private var isShowingLogin = false

    private var selection: Binding<Node.ID?> {
        Binding(get: { selectedNodeID }, set: { selectedNodeID = $0 ?? "" })
    }

    private var itemSelection: Binding<PersistentIdentifier?> {
        Binding(get: {
            if let selectedItem {
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(PersistentIdentifier.self, from: selectedItem)
                } catch {
                    return nil
                }
            } else {
                return nil
            }
        },
                set: {
            let encoder = JSONEncoder()
            do {
                selectedItem = try encoder.encode($0)
            } catch {
                selectedItem = nil
            }
        })
    }

//    private var selectedNode: Binding<Node> {
//        feedModel[selection.wrappedValue]
//    }


    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: selection)
                .environment(feedModel)
                .environment(favIconRepository)
        } detail: {
            ZStack {
                if feedModel.currentNodeID != Constants.emptyNodeGuid {
                    ItemsListView(itemSelection: itemSelection)
                        .environment(feedModel)
                        .environment(favIconRepository)
                        .toolbar {
                            ItemListToolbarContent(node: feedModel.currentNode)
                        }
                } else {
                    Text("No Feed Selected")
                        .font(.largeTitle).fontWeight(.light)
                        .foregroundColor(.secondary)
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
