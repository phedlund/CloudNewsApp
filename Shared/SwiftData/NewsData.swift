//
//  NewsData.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/10/23.
//

import SwiftData

class NewsData {

    static let shared = NewsData()

    let newsSchema = Schema([
            Feeds.self,
            Feed.self,
            Folder.self,
            Item.self
        ])

    var container: ModelContainer?

    init() {
        let config = ModelConfiguration()
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
