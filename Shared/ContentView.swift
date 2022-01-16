//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @AppStorage(StorageKeys.isloggedIn) private var isLoggedIn = false
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject private var nodeTree = FeedModel()

    @State private var isShowingLogin = false

    init() {
        if let cssTemplateURL = Bundle.main.url(forResource: "rss", withExtension: "css") {
            do {
                let cssTemplate = try String(contentsOf: cssTemplateURL, encoding: .utf8)
                if let tempDir = tempDirectory() {
                    try cssTemplate.write(to: tempDir.appendingPathComponent("rss.css"), atomically: true, encoding: .utf8)
                }
            } catch { }
        }
//        async {
//            do {
//                try await NewsManager().initialSync()
//            } catch  {
////
//            }
//        }
    }

    var body: some View {
        NavigationView {
            SidebarView()
                .environmentObject(nodeTree)
            ItemsView(node: Node())
                .environmentObject(nodeTree)
        }
        .onAppear {
            isShowingLogin = !isLoggedIn
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
