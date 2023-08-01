//
//  NewsData.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/10/23.
//

import SwiftData

class NewsData {

    static let shared = NewsData()

    let fullSchema = Schema([
            Feeds.self,
            Feed.self,
            Folder.self,
            Item.self
        ])

    let news = ModelConfiguration(
            schema: Schema([
                Feeds.self,
                Feed.self,
                Folder.self,
                Item.self
            ])
        )

    var container: ModelContainer?

    init() {
        do {
            container = try ModelContainer(for: fullSchema, news)
        } catch {
            print(error.localizedDescription)
        }
    }

    func resetDatabase() {
        //
    }
}
