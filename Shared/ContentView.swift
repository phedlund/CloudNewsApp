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
    
    @State private var isShowingLogin = false
    
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
            .sheet(isPresented: $isShowingLogin, onDismiss: nil) {
                NavigationView {
                    SettingsView()
                }
            }
#if !os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                print("Moving to the background!")
                appDelegate.scheduleAppRefresh()
                appDelegate.scheduleImageFetch()
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
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationView {
                SidebarView()
                    .environmentObject(nodeTree)
                    .environmentObject(preferences)
                Text("No Feed Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
            .navigationViewStyle(.stack)
        } else {
            NavigationView {
                SidebarView()
                    .environmentObject(nodeTree)
                    .environmentObject(preferences)
                Text("No Feed Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
            .navigationViewStyle(.columns)
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
