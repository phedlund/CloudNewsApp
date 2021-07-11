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
    @StateObject private var nodeTree = FeedTreeModel()

    init() {
        if let cssTemplateURL = Bundle.main.url(forResource: "rss", withExtension: "css") {
            do {
                let cssTemplate = try String(contentsOf: cssTemplateURL, encoding: .utf8)
                if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try cssTemplate.write(to: docDir.appendingPathComponent("rss.css"), atomically: true, encoding: .utf8)
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
            ItemsView(node: nodeTree.feedTree.children![0])
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
