//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI
import URLImage
import URLImageStore

@main
struct CloudNewsApp: App {

    @StateObject var treeModel = FeedTreeModel()

    var body: some Scene {
        let fileStore = URLImageFileStore()
        let inMemoryStore = URLImageInMemoryStore()
        let urlImageService = URLImageService(fileStore: fileStore, inMemoryStore: inMemoryStore)

        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, NewsData.mainThreadContext)
                .environment(\.urlImageService, urlImageService)
                .environmentObject(treeModel)
        }
    }
}
