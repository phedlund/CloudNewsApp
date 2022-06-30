//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
#if !os(macOS)
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    @KeychainStorage(StorageKeys.username) var username: String = ""
    @KeychainStorage(StorageKeys.password) var password: String = ""

    @ObservedObject var model: FeedModel
    @ObservedObject var settings: Preferences

    private let onNewFeed = NotificationCenter.default
        .publisher(for: .newFeed)
        .receive(on: RunLoop.main)

    private let onNewFolder = NotificationCenter.default
        .publisher(for: .newFolder)
        .receive(on: RunLoop.main)

    @State private var isShowingLogin = false
    @State private var addSheet: AddType?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var nodeSelection: Node.ID?
    @State private var itemSelection: ArticleModel.ID?

    private var isNotLoggedIn: Bool {
#if !os(macOS)
        return username.isEmpty || password.isEmpty
#else
        return false
#endif
    }
    
    var body: some View {
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } detail: {
            ZStack {
                if let nodeSelection, let node = model.node(for: nodeSelection) {
                    ItemsView(node: node, itemSelection: $itemSelection)
                        .environmentObject(settings)
                } else {
                    Text("No Feed Selected")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            isShowingLogin = isNotLoggedIn
        }
        .sheet(isPresented: $isShowingLogin) {
            NavigationView {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("Moving to the background!")
            appDelegate.scheduleAppRefresh()
            appDelegate.scheduleImageFetch()
        }
#else
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } content: {
            if let nodeSelection, let node = model.node(for: nodeSelection) {
                ItemsView(node: node, itemSelection: $itemSelection)
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .environmentObject(settings)
            } else {
                Text("No Feed Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let nodeSelection, let itemSelection, let item = model.node(for: nodeSelection)?.item(for: itemSelection) {
                MacArticleView(articleModel: item)
            } else {
                Text("No Article Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
        }
        .sheet(item: $addSheet) { sheet in
            switch sheet {
            case .feed:
                VStack {
                    AddView(.feed)
                }
                .padding()
                .frame(minWidth: 400)
            case .folder:
                VStack {
                    AddView(.folder)
                }
                .padding()
                .frame(minWidth: 400)
            }
        }
        .onReceive(onNewFeed) { _ in
            addSheet = .feed
        }
        .onReceive(onNewFolder) { _ in
            addSheet = .folder
        }
#endif
    }
    
}

struct ContentView_Previews: PreviewProvider {
    struct Preview: View {
        @StateObject private var model = FeedModel()
        @StateObject private var settings = Preferences()
        var body: some View {
            ContentView(model: model, settings: settings)
        }
    }
    static var previews: some View {
        Preview()
    }}

