//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appDelegate: AppDelegate
    @KeychainStorage(StorageKeys.username) var username: String = ""
    @KeychainStorage(StorageKeys.password) var password: String = ""

    @StateObject private var nodeTree = FeedModel()

    @State private var isShowingLogin = false

    private var isNotLoggedIn: Bool {
        return username.isEmpty || password.isEmpty
    }

    var body: some View {
        NodesView()
        .onAppear {
            isShowingLogin = isNotLoggedIn
        }
        .sheet(isPresented: $isShowingLogin, onDismiss: nil) {
            NavigationView {
                SettingsView(showModal: .constant(true))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("Moving to the background!")
            appDelegate.scheduleAppRefresh()
            appDelegate.scheduleImageFetch()
        }
    }

}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, NewsData.mainThreadContext)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

struct NodesView: View {
    @StateObject private var nodeTree = FeedModel()

    @ViewBuilder
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationView {
                SidebarView()
                    .environmentObject(nodeTree)
            }
            .navigationViewStyle(.stack)
        } else {
            NavigationView {
                SidebarView()
                    .environmentObject(nodeTree)
                ItemsView(node: Node())
                    .environmentObject(nodeTree)
            }
            .navigationViewStyle(.automatic)
        }
    }

}
