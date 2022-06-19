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

    private let onNewFeed = NotificationCenter.default
        .publisher(for: .newFeed)
        .receive(on: RunLoop.main)

    private let onNewFolder = NotificationCenter.default
        .publisher(for: .newFolder)
        .receive(on: RunLoop.main)

    @State private var isShowingLogin = false
    @State private var addSheet: AddType?

    private var isNotLoggedIn: Bool {
#if !os(macOS)
        return username.isEmpty || password.isEmpty
#else
        return false
#endif
    }
    
    var body: some View {
        NodesView()
            .onAppear {
                isShowingLogin = isNotLoggedIn
            }
#if !os(macOS)
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
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

struct NodesView: View {
    @StateObject private var nodeTree: FeedModel
    @StateObject private var preferences: Preferences

    init() {
        self._nodeTree = StateObject(wrappedValue: FeedModel())
        self._preferences = StateObject(wrappedValue: Preferences())
    }
    
    @ViewBuilder
    var body: some View {
#if !os(macOS)
        NavigationSplitView {
            SidebarView()
                .environmentObject(nodeTree)
                .environmentObject(preferences)
        } detail: {
            Text("No Feed Selected")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
        }
#else
        NavigationView {
            SidebarView()
                .environmentObject(nodeTree)
                .environmentObject(preferences)
            Text("No Feed Selected")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .toolbar {
                    ToolbarItem {
                        Spacer()
                    }
                }
            Text("No Article Selected")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .toolbar {
                    ToolbarItem {
                        Spacer()
                    }
                }
        }
        .navigationViewStyle(.columns)
#endif
    }
    
}
