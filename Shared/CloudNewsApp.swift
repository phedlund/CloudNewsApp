//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI

@main
struct CloudNewsApp: App {

    @StateObject var treeModel = FeedTreeModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, NewsData.mainThreadContext)
                .environmentObject(treeModel)
        }
    }
}
