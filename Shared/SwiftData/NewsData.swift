//
//  NewsData.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/10/23.
//

import SwiftData

class NewsData {

    @MainActor static let shared = NewsData()

    let newsSchema = Schema([
            Feeds.self,
            Feed.self,
            Folder.self,
            Item.self,
            Read.self,
            Unread.self,
            Starred.self,
            Unstarred.self,
            Node.self
        ])

    var container: ModelContainer?

    init() {
        do {
            container = try ModelContainer(for: newsSchema, configurations: ModelConfiguration())
        } catch {
            print(error.localizedDescription)
        }
    }

    func resetDatabase() {
        //
    }
}
